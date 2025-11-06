# Branch-Yield: Decentralized Identity and Reputation System

Branch-Yield is a privacy-preserving decentralized identity platform that enables secure badge verification across multiple domains using zero-knowledge proofs and selective disclosure technology. The system allows users to prove their credentials and achievements without exposing sensitive personal information, creating a trustworthy ecosystem for digital identity management. Built on blockchain technology, it provides a novel approach to credential verification that maintains privacy while ensuring authenticity.

# Branch-Yield: Decentralized Identity and Reputation System

## Overview

Branch-Yield is a privacy-preserving decentralized identity platform built on Stacks blockchain that enables secure badge verification across multiple domains using zero-knowledge proofs and selective disclosure technology. The system allows users to prove their credentials and achievements without exposing sensitive personal information, creating a trustworthy ecosystem for digital identity management.

## Features

- **Decentralized Badge Issuance**: Credential providers can register as issuers and create verifiable digital badges
- **Reputation Staking**: Economic incentives through token staking that can be slashed during disputes
- **Zero-Knowledge Commitments**: Privacy-preserving credential verification using cryptographic commitments
- **Off-Chain Storage**: Integration with IPFS for encrypted credential data storage
- **Dispute Resolution**: Decentralized mechanism for challenging fraudulent credentials
- **Expiration Management**: Automated handling of time-bound credentials
- **Cross-Platform Verification**: Standardized badge schemas for interoperability

## Architecture

### Dual-Layer Design

1. **On-Chain Layer** (Smart Contract):
   - Badge schema definitions
   - Credential commitments and verification
   - Issuer registry and reputation management
   - Dispute resolution logic
   - Stake management

2. **Off-Chain Layer** (IPFS):
   - Encrypted credential details
   - Supporting documentation
   - Privacy-sensitive metadata

### Key Components

#### 1. Issuer Registry
Badge issuers must stake a minimum amount of STX tokens to participate in the network. This creates economic accountability.

#### 2. Badge Schemas
Templates that define the structure, criteria, and validity period of credentials.

#### 3. Badge Instances
Individual credentials issued to users, linked to schemas with zero-knowledge commitments.

#### 4. Dispute System
Allows community members to challenge fraudulent credentials with economic stakes.

## Smart Contract Specification

### Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `min-issuer-stake` | 1,000,000 μSTX | Minimum stake for badge issuers |
| `dispute-timelock` | 144 blocks | ~24 hour dispute resolution period |
| `platform-fee` | 50,000 μSTX | Fee per badge issuance |

### Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | `err-owner-only` | Action restricted to contract owner |
| u101 | `err-not-found` | Resource not found |
| u102 | `err-unauthorized` | Caller not authorized |
| u103 | `err-already-exists` | Resource already exists |
| u104 | `err-invalid-badge` | Invalid badge data |
| u105 | `err-insufficient-stake` | Insufficient stake amount |
| u106 | `err-badge-expired` | Badge has expired |
| u107 | `err-dispute-exists` | Dispute already exists |
| u108 | `err-invalid-dispute` | Invalid dispute state |
| u109 | `err-insufficient-funds` | Insufficient funds for operation |

## Usage Guide

### For Badge Issuers

#### 1. Register as an Issuer

```clarity
(contract-call? .branch-yield register-issuer "University XYZ")
```

This requires staking the minimum amount (1,000,000 μSTX).

#### 2. Create a Badge Schema

```clarity
(contract-call? .branch-yield create-badge-schema 
    "Computer Science Degree"
    "Bachelor of Science in Computer Science from University XYZ"
    0x1234... ;; criteria hash
    u52560   ;; expires in ~1 year (blocks)
)
```

#### 3. Issue a Badge

```clarity
(contract-call? .branch-yield issue-badge
    u1                           ;; schema-id
    'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM ;; holder address
    0xabcd...                    ;; zero-knowledge commitment
    "QmXYZ..."                   ;; IPFS hash of encrypted data
)
```

#### 4. Manage Stake

Add more stake for higher reputation:
```clarity
(contract-call? .branch-yield add-issuer-stake u500000)
```

Withdraw excess stake:
```clarity
(contract-call? .branch-yield withdraw-issuer-stake u200000)
```

#### 5. Revoke a Badge

```clarity
(contract-call? .branch-yield revoke-badge u1)
```

### For Badge Holders

#### Verify Your Badge

```clarity
(contract-call? .branch-yield verify-badge u1)
```

Returns badge validity status and metadata.

#### Check Your Badges

```clarity
(contract-call? .branch-yield get-user-badges 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### For Verifiers

#### Check if User Has Specific Badge Type

```clarity
(contract-call? .branch-yield has-badge-schema 
    'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM 
    u1
)
```

#### Verify Badge Details

```clarity
(contract-call? .branch-yield get-badge u1)
```

### For Dispute Resolution

#### Create a Dispute

Any user can challenge a potentially fraudulent badge:

```clarity
(contract-call? .branch-yield create-dispute 
    u1 
    "Badge holder did not meet graduation requirements"
)
```

Requires staking 500,000 μSTX.

#### Resolve Dispute (Admin Only)

```clarity
(contract-call? .branch-yield resolve-dispute u1 true) ;; true = challenger wins
```

## Data Structures

### Issuer

```clarity
{
    name: (string-ascii 64),
    stake-amount: uint,
    badges-issued: uint,
    reputation-score: uint,
    active: bool,
    registered-at: uint
}
```

### Badge Schema

```clarity
{
    issuer: principal,
    name: (string-ascii 64),
    description: (string-ascii 256),
    criteria-hash: (buff 32),
    expiration-period: uint,
    created-at: uint,
    active: bool
}
```

### Badge

```clarity
{
    schema-id: uint,
    holder: principal,
    issuer: principal,
    commitment: (buff 32),
    ipfs-hash: (string-ascii 64),
    issued-at: uint,
    expires-at: uint,
    revoked: bool
}
```

### Dispute

```clarity
{
    badge-id: uint,
    challenger: principal,
    issuer: principal,
    reason: (string-ascii 256),
    stake-amount: uint,
    created-at: uint,
    resolved: bool,
    resolution: (optional bool)
}
```

## Security Features

### Economic Security
- **Issuer Staking**: Minimum stake requirement ensures issuers have skin in the game
- **Dispute Stakes**: Challengers must stake tokens to prevent spam disputes
- **Slashing**: Fraudulent issuers lose staked tokens
- **Platform Fees**: Per-badge fees prevent spam and fund platform operations

### Privacy Protection
- **Zero-Knowledge Commitments**: Credentials verified without revealing details
- **Off-Chain Storage**: Sensitive data stored encrypted in IPFS
- **Selective Disclosure**: Users can prove specific attributes without full exposure

### Integrity Mechanisms
- **Immutable Records**: On-chain badge records cannot be altered
- **Revocation Tracking**: Revoked badges remain visible with revocation status
- **Reputation Scoring**: Dynamic issuer reputation based on disputes and activity
- **Timelock Disputes**: 24-hour period ensures fair dispute resolution

## Deployment

### Prerequisites

1. Stacks CLI installed
2. Testnet/Mainnet STX tokens for deployment
3. Clarinet for local testing (optional)

### Deploy to Testnet

```bash
# Using Stacks CLI
stacks-cli deploy branch-yield.clar --testnet

# Or using Clarinet
clarinet deploy --testnet
```

### Deploy to Mainnet

```bash
stacks-cli deploy branch-yield.clar --mainnet
```

## Use Cases

### Professional Certifications
- IT certifications (CompTIA, Cisco, AWS)
- Professional licenses (CPA, Bar, Medical)
- Industry-specific credentials

### Educational Achievements
- Academic degrees and diplomas
- Course completion certificates
- Continuing education credits

### Compliance Verification
- Healthcare provider credentials
- Financial advisor certifications
- Background check results
- Security clearances

### Employment Verification
- Anonymous credential presentation for job applications
- Skills verification without revealing full resume
- Work history validation

## Integration Examples

### Web Application Integration

```javascript
// Connect to Stacks wallet
const { openContractCall } = require('@stacks/connect');

// Issue a badge
await openContractCall({
  contractAddress: 'SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR',
  contractName: 'branch-yield',
  functionName: 'issue-badge',
  functionArgs: [
    uintCV(1), // schema-id
    principalCV(holderAddress),
    bufferCV(commitment),
    stringCV(ipfsHash)
  ]
});
```

### API Integration

Create a REST API wrapper for common operations:

```javascript
const express = require('express');
const { callReadOnlyFunction } = require('@stacks/transactions');

app.get('/verify-badge/:badgeId', async (req, res) => {
  const result = await callReadOnlyFunction({
    contractAddress: 'SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR',
    contractName: 'branch-yield',
    functionName: 'verify-badge',
    functionArgs: [uintCV(req.params.badgeId)]
  });
  
  res.json(result);
});
```
## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Submit a pull request with detailed description

## Security Considerations

- Always verify badge schemas before issuing credentials
- Store private keys securely when managing issuer accounts
- Monitor dispute activity for your issued badges
- Keep IPFS data encrypted and backed up
- Regularly audit issuer reputation scores
