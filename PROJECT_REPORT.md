# COURSE REGISTRATION LEDGER
## Blockchain Mini Project — Complete Documentation
### Department of Computer Science & Engineering

---

## TEAM & CONTRIBUTIONS

| Member | Role | Contribution |
|--------|------|--------------|
| **Member 1** | Lead Developer, Smart Contract Architect, Frontend Developer | **85%** |
| Member 2 | Testing & Deployment Support | 10% |
| Member 3 | Documentation & UI Assistance | 5% |

**Member 1 Detailed Contributions:**
- Designed and wrote the entire Solidity smart contract (CourseRegistrationLedger.sol)
- Implemented all Solidity concepts: structs, enums, mappings, events, modifiers, custom errors, fallback, overloading, withdrawal pattern, ether units
- Designed and built the complete React/HTML frontend DApp (index.html)
- Integrated ethers.js for MetaMask + Ganache connectivity
- Implemented event-driven live ledger updates
- Wrote the full project documentation
- Deployed and tested on Ganache + Remix

---

## 1. PROBLEM STATEMENT

Traditional course registration systems rely on centralized databases that suffer from:
- **Data manipulation**: Administrators or insiders can alter records
- **Over-enrollment errors**: Race conditions during peak registration cause inconsistent seat counts
- **Lack of transparency**: Students cannot verify seat availability is real-time and honest
- **No audit trail**: No permanent, tamper-proof record of who registered when

---

## 2. PROPOSED SOLUTION

A **decentralized blockchain-based course registration ledger** using:
- Ethereum smart contracts (Solidity) for all business logic
- Every action (enroll, drop, create course) is an on-chain transaction
- Immutable event logs form a permanent audit trail
- Smart contract enforces capacity rules — over-enrollment is mathematically impossible

---

## 3. CONSENSUS ALGORITHM: PROOF OF AUTHORITY (PoA)

### Chosen Algorithm: Proof of Authority (PoA)

**Justification for a Campus-Level Permissioned Environment:**

| Criterion | Why PoA Fits |
|-----------|-------------|
| **Permissioned environment** | University has known, trusted entities (Registrar, Dept Heads) who act as validators |
| **High throughput** | PoA produces blocks rapidly — critical during peak registration periods |
| **No mining overhead** | No wasteful computation; energy-efficient for an institution |
| **Accountability** | Validators are real people (staff) who are legally and professionally accountable |
| **Sybil resistance** | In a closed campus network, fake identities are prevented by institutional control |
| **Low latency** | Students get near-instant confirmation of enrollment |

**Contrast with alternatives:**
- **Proof of Work (PoW)**: Wasteful mining makes no sense in a university setting
- **Proof of Stake (PoS)**: Requires token staking — irrelevant in an academic context
- **PBFT**: Suitable but complex; PoA is simpler and sufficient for this scale

**How PoA is modeled in our contract:**
The `authorizedValidators` mapping implements PoA — only the admin can add/remove validators. Validators (e.g., department registrars) can enroll/drop students on behalf of the institution. Regular students can only self-register and self-drop.

---

## 4. SMART CONTRACT ARCHITECTURE

### File: `CourseRegistrationLedger.sol`

### 4.1 Solidity Concepts Used (Checklist)

| Concept | Where Used |
|---------|-----------|
| **Structs** | `Student`, `Course`, `RegistrationRecord` |
| **Enums** | `RegistrationStatus`, `CourseStatus`, `StudentStatus` |
| **Mappings** | `students`, `courses`, `records`, `enrollmentStatus`, `walletToStudentId`, `authorizedValidators` |
| **Arrays** | `enrolledCourses[]`, `courseStudents[]`, `courseWaitlist[]` |
| **Events** | `StudentEnrolled`, `StudentDropped`, `CourseCreated`, `WaitlistPromoted`, etc. |
| **Modifiers** | `onlyAdmin`, `onlyValidator`, `studentExists`, `courseExists`, `courseActive`, `studentActive` |
| **Public visibility** | `students`, `courses`, `admin`, `totalFeesCollected` |
| **Private visibility** | `_enroll()`, `_drop()`, `_addToWaitlist()`, `_createRecord()`, `pendingWithdrawals` |
| **Internal visibility** | (accessible to derived contracts) |
| **External visibility** | `enrollCourse`, `dropCourse`, `registerStudent`, `getStudent`, `getCourse` |
| **View functions** | `getStudent()`, `getCourse()`, `getEnrollmentStatus()`, `getAvailableSeats()` |
| **Pure functions** | `calculateFillPercentage()` — no state access |
| **Fallback function** | `fallback()` and `receive()` — rejects random ether |
| **Overloading** | `suspendStudent(uint256)` and `suspendStudent(address)` |
| **Withdrawal pattern** | `pendingWithdrawals` + `withdraw()` — prevents reentrancy |
| **Ether units** | `registrationFee` in Wei, `msg.value` checks |
| **Custom errors** | `Unauthorized`, `CourseAtCapacity`, `AlreadyEnrolled`, `InsufficientFee`, etc. |
| **Constructor** | Initializes admin, counters, and first validator |
| **Payable** | `enrollCourse()` is payable — collects fees |
| **Restricted Access** | `onlyAdmin` and `onlyValidator` modifiers |
| **Mathematical functions** | `calculateFillPercentage()` uses arithmetic |

### 4.2 Data Structures

```
Student:       studentId | name | email | status | registeredAt | enrolledCourses[] | exists
Course:        courseId | courseName | courseCode | instructor | maxCapacity | currentEnrollment | waitlistCount | creditHours | status | registrationFee | exists
RegistrationRecord: recordId | studentId | courseId | status | timestamp | recordedBy | action
```

### 4.3 Key Functions

**Student Flow:**
1. `registerStudent(name, email)` → assigns unique studentId, links wallet
2. `enrollCourse(courseId)` → checks capacity → enrolls or waitlists → emits event
3. `dropCourse(courseId, reason)` → drops → promotes waitlisted student automatically

**Admin Flow:**
1. `createCourse(...)` → creates course with capacity and fee
2. `updateCourseCapacity(...)` → adjusts seats (cannot go below current enrollment)
3. `addValidator(address)` → PoA: grants registrar-level authority
4. `adminEnrollStudent(studentId, courseId)` → manual enrollment

**Waitlist Management (Automatic):**
- When course is full → `_addToWaitlist()` called automatically
- When someone drops → `_promoteFromWaitlist()` called automatically
- FIFO (first in, first out) order

### 4.4 Security Features

1. **Reentrancy Guard**: Withdrawal pattern resets balance before transfer
2. **Over-enrollment Prevention**: `currentEnrollment >= maxCapacity` check before every enroll
3. **Duplicate Enrollment Prevention**: `AlreadyEnrolled` custom error
4. **Access Control**: Three-tier system (student / validator / admin)
5. **Input Validation**: Empty string checks, range checks on credit hours/capacity
6. **Fallback Protection**: `fallback()` and `receive()` reject accidental ETH sends

---

## 5. FRONTEND (DApp)

### File: `index.html`

**Technology:** Vanilla HTML/CSS/JavaScript + ethers.js v5.7

**Pages/Tabs:**
1. **Browse Courses** — live course grid from blockchain, capacity bars, seat counts
2. **Register / Enroll** — student registration form, enroll/drop with MetaMask confirmation
3. **My Records** — student profile, enrolled courses, transaction history
4. **Admin Panel** — create courses, update capacity, add validators, manual enrollment
5. **Full Ledger** — live event log, record queries, roster lookup, enrollment status check

**Features:**
- MetaMask wallet connection (configured for Ganache local network)
- Real-time event streaming via ethers.js event listeners
- Automatic UI update on every transaction
- Toast notifications for transaction status
- Course detail modal with enrollment action
- Capacity progress bars (green/amber/red based on fill %)
- Block number display, network name detection

---

## 6. DEPLOYMENT GUIDE (Step-by-Step)

### Step 1: Start Ganache
- Open Ganache desktop app
- Start a new workspace (default: HTTP port 7545)
- Note the RPC URL: `http://127.0.0.1:7545`
- Note the Chain ID: `1337`

### Step 2: Connect MetaMask to Ganache
1. Open MetaMask → Click network dropdown → "Add Network"
2. Network Name: `Ganache Local`
3. RPC URL: `http://127.0.0.1:7545`
4. Chain ID: `1337`
5. Currency: `ETH`
6. Import a Ganache account: Copy private key from Ganache → MetaMask → Import Account

### Step 3: Deploy Contract in Remix
1. Open https://remix.ethereum.org
2. Create new file → paste `CourseRegistrationLedger.sol`
3. Compile with Solidity compiler `^0.8.19`
4. Go to "Deploy & Run Transactions"
5. Environment: **Custom - External Http Provider**
6. RPC URL: `http://127.0.0.1:7545`
7. Select your Ganache account
8. Click **Deploy**
9. Copy the deployed contract address

### Step 4: Configure Frontend
1. Open `index.html`
2. Find line: `const CONTRACT_ADDRESS = "0x000..."`
3. Replace with your deployed contract address
4. Open `index.html` in a browser (or use Live Server in VS Code)

### Step 5: Test the DApp
1. Connect MetaMask (owner account)
2. Admin Panel → Create some courses
3. Switch to a different Ganache account in MetaMask
4. Register as Student → Enroll in a course
5. Watch the Live Ledger update in real-time!

---

## 7. TEST SCENARIOS

| Scenario | Expected Behavior |
|----------|------------------|
| Student registers twice from same wallet | Reverts: "Wallet already registered" |
| Student enrolls when course is full | Auto-waitlisted, event emitted |
| Another student drops → waitlisted student | Auto-promoted via `_promoteFromWaitlist()` |
| Non-admin tries to create course | Reverts: `Unauthorized` |
| Enroll with insufficient fee | Reverts: `InsufficientFee` |
| Admin updates capacity below enrollment | Reverts: invalid input |

---

## 8. INNOVATION & ENHANCEMENTS

1. **Automatic Waitlist Promotion**: When a student drops, the contract automatically promotes the next waitlisted student — no admin intervention needed
2. **Three-Tier Authority (PoA Model)**: Students, Validators (dept heads), Admin — mirrors real university hierarchy
3. **Pull Payment Pattern**: Registration fees are collected securely using the withdrawal pattern to prevent reentrancy attacks
4. **Dual Overloaded Functions**: `suspendStudent()` works with both student ID and wallet address
5. **Pure Fill Percentage Function**: Off-chain calculation exposed for UI use without gas cost
6. **Custom Errors**: Gas-efficient error handling with descriptive error types
7. **Comprehensive Event Log**: Every state change emits an event, enabling full auditability
8. **Live Event Streaming Frontend**: DApp subscribes to contract events and updates UI in real-time

---

## 9. CONCLUSION

The Course Registration Ledger successfully addresses all stated requirements:
- ✅ Transparent, tamper-proof blockchain ledger for all registrations
- ✅ Smart contract enforcement of capacity limits (over-enrollment impossible)
- ✅ Add/drop workflow with waitlist management
- ✅ Unique IDs for students (wallet-linked) and courses (sequential)
- ✅ Proof of Authority consensus with justification
- ✅ Comprehensive use of Solidity concepts from syllabus
- ✅ Full-featured frontend DApp with MetaMask integration
- ✅ Clean, commented, well-structured code

---

*Submitted for Mini Project Evaluation | Blockchain Technology Course*
