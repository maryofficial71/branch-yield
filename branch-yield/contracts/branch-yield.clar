;; Branch-Yield: Decentralized Identity and Reputation System
;; A privacy-preserving credential verification platform with reputation staking

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-badge (err u104))
(define-constant err-insufficient-stake (err u105))
(define-constant err-badge-expired (err u106))
(define-constant err-dispute-exists (err u107))
(define-constant err-invalid-dispute (err u108))
(define-constant err-insufficient-funds (err u109))

;; Minimum stake required for badge issuers (in microSTX)
(define-constant min-issuer-stake u1000000)

;; Dispute resolution timelock (blocks)
(define-constant dispute-timelock u144) ;; ~24 hours

;; Data Variables
(define-data-var platform-fee uint u50000) ;; Platform fee in microSTX
(define-data-var total-issuers uint u0)
(define-data-var total-badges uint u0)

;; Data Maps

;; Badge Issuers Registry
(define-map issuers
    principal
    {
        name: (string-ascii 64),
        stake-amount: uint,
        badges-issued: uint,
        reputation-score: uint,
        active: bool,
        registered-at: uint
    }
)

;; Badge Definitions (Templates)
(define-map badge-schemas
    uint ;; schema-id
    {
        issuer: principal,
        name: (string-ascii 64),
        description: (string-ascii 256),
        criteria-hash: (buff 32), ;; Hash of criteria stored off-chain
        expiration-period: uint, ;; in blocks, 0 for non-expiring
        created-at: uint,
        active: bool
    }
)

;; Issued Badges (Credentials)
(define-map badges
    uint ;; badge-id
    {
        schema-id: uint,
        holder: principal,
        issuer: principal,
        commitment: (buff 32), ;; Zero-knowledge commitment
        ipfs-hash: (string-ascii 64), ;; Off-chain encrypted data
        issued-at: uint,
        expires-at: uint,
        revoked: bool
    }
)

;; User Badge Registry (holder -> list of badge IDs)
(define-map user-badges
    principal
    (list 100 uint)
)

;; Disputes
(define-map disputes
    uint ;; dispute-id
    {
        badge-id: uint,
        challenger: principal,
        issuer: principal,
        reason: (string-ascii 256),
        stake-amount: uint,
        created-at: uint,
        resolved: bool,
        resolution: (optional bool) ;; true = challenger wins, false = issuer wins
    }
)

(define-data-var next-schema-id uint u1)
(define-data-var next-badge-id uint u1)
(define-data-var next-dispute-id uint u1)

;; Issuer Management Functions

;; Register as a badge issuer with stake
(define-public (register-issuer (name (string-ascii 64)))
    (let
        (
            (sender tx-sender)
        )
        (asserts! (is-none (map-get? issuers sender)) err-already-exists)
        (try! (stx-transfer? min-issuer-stake sender (as-contract tx-sender)))
        (map-set issuers sender {
            name: name,
            stake-amount: min-issuer-stake,
            badges-issued: u0,
            reputation-score: u100,
            active: true,
            registered-at: block-height
        })
        (var-set total-issuers (+ (var-get total-issuers) u1))
        (ok true)
    )
)

;; Add stake to issuer account
(define-public (add-issuer-stake (amount uint))
    (let
        (
            (sender tx-sender)
            (issuer-data (unwrap! (map-get? issuers sender) err-not-found))
        )
        (try! (stx-transfer? amount sender (as-contract tx-sender)))
        (map-set issuers sender 
            (merge issuer-data { 
                stake-amount: (+ (get stake-amount issuer-data) amount)
            })
        )
        (ok true)
    )
)

;; Withdraw stake (if no active disputes and sufficient remaining)
(define-public (withdraw-issuer-stake (amount uint))
    (let
        (
            (sender tx-sender)
            (issuer-data (unwrap! (map-get? issuers sender) err-not-found))
            (new-stake (- (get stake-amount issuer-data) amount))
        )
        (asserts! (>= new-stake min-issuer-stake) err-insufficient-stake)
        (try! (as-contract (stx-transfer? amount tx-sender sender)))
        (map-set issuers sender 
            (merge issuer-data { stake-amount: new-stake })
        )
        (ok true)
    )
)

;; Badge Schema Management

;; Create a new badge schema/template
(define-public (create-badge-schema 
    (name (string-ascii 64))
    (description (string-ascii 256))
    (criteria-hash (buff 32))
    (expiration-period uint)
)
    (let
        (
            (sender tx-sender)
            (schema-id (var-get next-schema-id))
        )
        (asserts! (is-some (map-get? issuers sender)) err-unauthorized)
        (map-set badge-schemas schema-id {
            issuer: sender,
            name: name,
            description: description,
            criteria-hash: criteria-hash,
            expiration-period: expiration-period,
            created-at: block-height,
            active: true
        })
        (var-set next-schema-id (+ schema-id u1))
        (ok schema-id)
    )
)

;; Deactivate a badge schema
(define-public (deactivate-schema (schema-id uint))
    (let
        (
            (sender tx-sender)
            (schema (unwrap! (map-get? badge-schemas schema-id) err-not-found))
        )
        (asserts! (is-eq sender (get issuer schema)) err-unauthorized)
        (map-set badge-schemas schema-id 
            (merge schema { active: false })
        )
        (ok true)
    )
)

;; Badge Issuance

;; Issue a badge to a holder
(define-public (issue-badge
    (schema-id uint)
    (holder principal)
    (commitment (buff 32))
    (ipfs-hash (string-ascii 64))
)
    (let
        (
            (sender tx-sender)
            (schema (unwrap! (map-get? badge-schemas schema-id) err-invalid-badge))
            (issuer-data (unwrap! (map-get? issuers sender) err-unauthorized))
            (badge-id (var-get next-badge-id))
            (expires-at (if (> (get expiration-period schema) u0)
                (+ block-height (get expiration-period schema))
                u0))
            (current-badges (default-to (list) (map-get? user-badges holder)))
        )
        (asserts! (is-eq sender (get issuer schema)) err-unauthorized)
        (asserts! (get active schema) err-invalid-badge)
        (asserts! (get active issuer-data) err-unauthorized)
        
        ;; Pay platform fee
        (try! (stx-transfer? (var-get platform-fee) sender contract-owner))
        
        ;; Create badge
        (map-set badges badge-id {
            schema-id: schema-id,
            holder: holder,
            issuer: sender,
            commitment: commitment,
            ipfs-hash: ipfs-hash,
            issued-at: block-height,
            expires-at: expires-at,
            revoked: false
        })
        
        ;; Update user badges list
        (map-set user-badges holder 
            (unwrap! (as-max-len? (append current-badges badge-id) u100) err-invalid-badge)
        )
        
        ;; Update issuer stats
        (map-set issuers sender 
            (merge issuer-data { 
                badges-issued: (+ (get badges-issued issuer-data) u1)
            })
        )
        
        (var-set next-badge-id (+ badge-id u1))
        (var-set total-badges (+ (var-get total-badges) u1))
        (ok badge-id)
    )
)

;; Revoke a badge
(define-public (revoke-badge (badge-id uint))
    (let
        (
            (sender tx-sender)
            (badge (unwrap! (map-get? badges badge-id) err-not-found))
        )
        (asserts! (is-eq sender (get issuer badge)) err-unauthorized)
        (map-set badges badge-id 
            (merge badge { revoked: true })
        )
        (ok true)
    )
)

;; Verification Functions

;; Verify badge is valid and active
(define-read-only (verify-badge (badge-id uint))
    (let
        (
            (badge (unwrap! (map-get? badges badge-id) err-not-found))
        )
        (ok {
            valid: (and 
                (not (get revoked badge))
                (or 
                    (is-eq (get expires-at badge) u0)
                    (< block-height (get expires-at badge))
                )
            ),
            holder: (get holder badge),
            issuer: (get issuer badge),
            issued-at: (get issued-at badge),
            expires-at: (get expires-at badge)
        })
    )
)

;; Check if user has a specific badge schema
(define-read-only (has-badge-schema (user principal) (schema-id uint))
    (let
        (
            (user-badge-list (default-to (list) (map-get? user-badges user)))
        )
        (ok (is-some (index-of? user-badge-list schema-id)))
    )
)

;; Dispute Resolution

;; Create a dispute against a badge
(define-public (create-dispute 
    (badge-id uint)
    (reason (string-ascii 256))
)
    (let
        (
            (sender tx-sender)
            (badge (unwrap! (map-get? badges badge-id) err-not-found))
            (dispute-id (var-get next-dispute-id))
            (stake-amount u500000) ;; Dispute stake
        )
        (asserts! (not (get revoked badge)) err-invalid-badge)
        (try! (stx-transfer? stake-amount sender (as-contract tx-sender)))
        
        (map-set disputes dispute-id {
            badge-id: badge-id,
            challenger: sender,
            issuer: (get issuer badge),
            reason: reason,
            stake-amount: stake-amount,
            created-at: block-height,
            resolved: false,
            resolution: none
        })
        
        (var-set next-dispute-id (+ dispute-id u1))
        (ok dispute-id)
    )
)

;; Resolve dispute (contract owner arbitration)
(define-public (resolve-dispute (dispute-id uint) (challenger-wins bool))
    (let
        (
            (dispute (unwrap! (map-get? disputes dispute-id) err-not-found))
            (issuer-data (unwrap! (map-get? issuers (get issuer dispute)) err-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (not (get resolved dispute)) err-invalid-dispute)
        (asserts! (>= block-height (+ (get created-at dispute) dispute-timelock)) err-invalid-dispute)
        
        (if challenger-wins
            (begin
                ;; Slash issuer stake and reward challenger
                (try! (as-contract (stx-transfer? (get stake-amount dispute) tx-sender (get challenger dispute))))
                (map-set issuers (get issuer dispute)
                    (merge issuer-data {
                        stake-amount: (- (get stake-amount issuer-data) (get stake-amount dispute)),
                        reputation-score: (if (> (get reputation-score issuer-data) u10)
                            (- (get reputation-score issuer-data) u10)
                            u0)
                    })
                )
                ;; Revoke the badge
                (let ((badge (unwrap! (map-get? badges (get badge-id dispute)) err-not-found)))
                    (map-set badges (get badge-id dispute)
                        (merge badge { revoked: true })
                    )
                )
            )
            (begin
                ;; Return stake to issuer, challenger loses stake
                (try! (as-contract (stx-transfer? (get stake-amount dispute) tx-sender (get issuer dispute))))
            )
        )
        
        (map-set disputes dispute-id
            (merge dispute {
                resolved: true,
                resolution: (some challenger-wins)
            })
        )
        (ok true)
    )
)

;; Read-only functions

(define-read-only (get-issuer (issuer principal))
    (ok (map-get? issuers issuer))
)

(define-read-only (get-badge-schema (schema-id uint))
    (ok (map-get? badge-schemas schema-id))
)

(define-read-only (get-badge (badge-id uint))
    (ok (map-get? badges badge-id))
)

(define-read-only (get-user-badges (user principal))
    (ok (map-get? user-badges user))
)

(define-read-only (get-dispute (dispute-id uint))
    (ok (map-get? disputes dispute-id))
)

(define-read-only (get-platform-stats)
    (ok {
        total-issuers: (var-get total-issuers),
        total-badges: (var-get total-badges),
        platform-fee: (var-get platform-fee)
    })
)

;; Admin functions

(define-public (update-platform-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set platform-fee new-fee)
        (ok true)
    )
)
