# Blockchain Course Registration Ledger

> A decentralized course registration system built using **Solidity**, **Ethereum**, and **Ethers.js**, enabling secure, transparent, and immutable academic enrollment through smart contracts.

---

## Overview

Traditional course registration systems rely on centralized databases, making them vulnerable to unauthorized modifications, single points of failure, and limited transparency.

This project implements a **blockchain-based course registration platform** where all enrollment transactions are executed through Ethereum smart contracts, ensuring data integrity, transparency, and tamper-resistant record keeping.

The system supports secure student enrollment, waitlist management, role-based access control, and immutable audit logs.

---

## Features

### Student Management
- Student registration
- Secure course enrollment
- Course withdrawal
- View enrolled courses

### Course Management
- Create and manage courses
- Course capacity enforcement
- Automatic seat availability updates
- Waitlist support

### Smart Contract Features
- Immutable enrollment records
- Role-based access control
- Event-driven transaction logging
- Secure Ether payment handling
- Custom Solidity errors for gas-efficient validation

### Blockchain Security
- Permissioned Proof-of-Authority (PoA) blockchain
- Transparent transaction history
- Tamper-resistant academic records
- Decentralized smart contract execution

---

# System Architecture

```
                   +----------------------+
                   |      Web Frontend    |
                   | HTML + JavaScript    |
                   +----------+-----------+
                              |
                        Ethers.js Library
                              |
                   +----------v-----------+
                   | Ethereum Smart       |
                   | Contract (Solidity)  |
                   +----------+-----------+
                              |
                       Ganache Blockchain
                     (Proof-of-Authority)
```

---

# Tech Stack

| Technology | Purpose |
|------------|---------|
| Solidity | Smart Contracts |
| Ethereum | Blockchain Platform |
| Ganache | Local Ethereum Network |
| Ethers.js | Smart Contract Interaction |
| JavaScript | Frontend Logic |
| HTML/CSS | User Interface |

---

# Smart Contract Modules

The smart contract implements:

- Student Registration
- Course Creation
- Course Enrollment
- Course Withdrawal
- Waitlist Management
- Ether Payment Validation
- Event Logging
- Access Control

---

# Key Concepts

This project demonstrates several blockchain engineering concepts including:

- Smart Contract Development
- Ethereum Transactions
- Immutable Ledger Design
- Role-Based Access Control
- Event-Driven Architecture
- Proof-of-Authority Consensus
- Secure State Management
- Decentralized Application (DApp) Development

---

# Project Structure

```
Blockchain-Course-Registration/

│
├── CourseRegistration.sol      # Solidity Smart Contract
├── index.html                  # Frontend Interface
├── PROJECT_REPORT.md           # Project Report
└── README.md
```

---

# Getting Started

## Prerequisites

- Node.js
- Ganache
- MetaMask
- Remix IDE (or Hardhat)
- Modern Web Browser

---

## Installation

Clone the repository

```bash
git clone https://github.com/Abhaypb/Blockchain-Course-Registration.git
cd Blockchain-Course-Registration
```

Launch Ganache and create a local blockchain.

Deploy the smart contract using Remix IDE or your preferred Ethereum development environment.

Configure MetaMask to connect to the Ganache network.

Open:

```
index.html
```

using a local web server.

---

# Example Workflow

1. Deploy the smart contract.
2. Register students.
3. Create available courses.
4. Enroll students into courses.
5. Automatically move students to the waitlist if a course is full.
6. Record all transactions permanently on the blockchain.
7. View enrollment events through blockchain logs.

---

# Learning Outcomes

This project demonstrates practical understanding of:

- Blockchain Application Development
- Solidity Programming
- Ethereum Smart Contracts
- Decentralized System Design
- Smart Contract Security
- Access Control Mechanisms
- Event-Based Programming
- Web3 Integration using Ethers.js

---

# Future Improvements

- JWT Authentication
- IPFS integration for decentralized storage
- NFT-based student identity
- Multi-university support
- Course prerequisite validation
- Administrative analytics dashboard
- Hardhat test suite
- Automated smart contract deployment pipeline

---

# Author

**Abhay Betageri**

- LinkedIn: https://www.linkedin.com/in/abhay-betageri-4ba976332/
- GitHub: https://github.com/Abhaypb

---

## License

This project is released under the **MIT License**.

---

> **Building transparent and tamper-resistant academic systems through blockchain technology.**
