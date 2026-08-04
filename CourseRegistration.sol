// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract CourseRegistrationLedger {

    // ===================== ENUMS =====================
    enum RegistrationStatus { NotEnrolled, Enrolled, Dropped, Waitlisted }
    enum CourseStatus       { Active, Inactive, Cancelled, Completed }
    enum StudentStatus      { Active, Suspended, Graduated }

    // ===================== STRUCTS =====================
    struct Student {
        uint256   studentId;
        string    name;
        string    email;
        StudentStatus status;
        uint256   registeredAt;
        uint256[] enrolledCourses; // tracks currently enrolled course IDs only
        bool      exists;
    }

    struct Course {
        uint256   courseId;
        string    courseName;
        string    courseCode;
        string    instructor;
        uint256   maxCapacity;
        uint256   currentEnrollment;
        uint256   waitlistCount;
        uint256   creditHours;
        CourseStatus status;
        uint256   registrationFee; // in wei
        bool      exists;
    }

    struct RegistrationRecord {
        uint256 recordId;
        uint256 studentId;
        uint256 courseId;
        RegistrationStatus status;
        uint256 timestamp;
        address recordedBy;
        string  action; // "ENROLLED" | "DROPPED" | "WAITLISTED" | "PROMOTED"
    }

    // ===================== STATE VARIABLES =====================
    address public  admin;
    uint256 private studentCounter; // starts at 1000
    uint256 private courseCounter;  // starts at 100
    uint256 private recordCounter;  // starts at 1
    uint256 public  totalFeesCollected;

    mapping(address => uint256) private pendingWithdrawals; // withdrawal pattern

    mapping(uint256 => Student)            public students;
    mapping(uint256 => Course)             public courses;
    mapping(uint256 => RegistrationRecord) public records;

    mapping(address => uint256) public walletToStudentId;
    mapping(uint256 => mapping(uint256 => RegistrationStatus)) public enrollmentStatus;
    mapping(uint256 => uint256[]) private courseStudents;  // enrolled students per course
    mapping(uint256 => uint256[]) private courseWaitlist;  // FIFO waitlist per course
    mapping(address => bool)      public  authorizedValidators; // PoA validators

    // ===================== EVENTS =====================
    event StudentRegistered    (uint256 indexed studentId, string name, address wallet, uint256 timestamp);
    event CourseCreated        (uint256 indexed courseId, string courseCode, string courseName, uint256 maxCapacity);
    event StudentEnrolled      (uint256 indexed studentId, uint256 indexed courseId, uint256 timestamp, address recordedBy);
    event StudentDropped       (uint256 indexed studentId, uint256 indexed courseId, uint256 timestamp, string reason);
    event StudentWaitlisted    (uint256 indexed studentId, uint256 indexed courseId, uint256 position);
    event WaitlistPromoted     (uint256 indexed studentId, uint256 indexed courseId, uint256 timestamp);
    event CourseCapacityUpdated(uint256 indexed courseId, uint256 oldCapacity, uint256 newCapacity);
    event CourseStatusChanged  (uint256 indexed courseId, CourseStatus newStatus);
    event ValidatorAdded       (address indexed validator, uint256 timestamp);
    event ValidatorRemoved     (address indexed validator);
    event FeeWithdrawn         (address indexed recipient, uint256 amount);

    // ===================== CUSTOM ERRORS =====================
    error Unauthorized(address caller);
    error StudentNotFound(uint256 studentId);
    error CourseNotFound(uint256 courseId);
    error CourseAtCapacity(uint256 courseId, uint256 maxCapacity);
    error AlreadyEnrolled(uint256 studentId, uint256 courseId);
    error NotEnrolled(uint256 studentId, uint256 courseId);
    error InsufficientFee(uint256 sent, uint256 required);
    error StudentSuspended(uint256 studentId);
    error CourseNotActive(uint256 courseId);
    error InvalidInput(string reason);

    // ===================== MODIFIERS =====================
    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized(msg.sender);
        _;
    }

    modifier onlyValidator() {
        if (!authorizedValidators[msg.sender] && msg.sender != admin)
            revert Unauthorized(msg.sender);
        _;
    }

    modifier studentExists(uint256 _sid) {
        if (!students[_sid].exists) revert StudentNotFound(_sid);
        _;
    }

    modifier courseExists(uint256 _cid) {
        if (!courses[_cid].exists) revert CourseNotFound(_cid);
        _;
    }

    modifier courseActive(uint256 _cid) {
        if (courses[_cid].status != CourseStatus.Active)
            revert CourseNotActive(_cid);
        _;
    }

    modifier studentActive(uint256 _sid) {
        if (students[_sid].status == StudentStatus.Suspended)
            revert StudentSuspended(_sid);
        _;
    }

    // ===================== CONSTRUCTOR =====================
    constructor() {
        admin = msg.sender;
        authorizedValidators[msg.sender] = true; // admin is PoA validator by default
        studentCounter = 1000;
        courseCounter  = 100;
        recordCounter  = 1;
    }

    // ===================== VALIDATOR MANAGEMENT (PoA) =====================

    function addValidator(address _validator) external onlyAdmin {
        require(_validator != address(0), "Cannot add zero address");
        require(_validator != admin,       "Admin is already a validator");
        require(!authorizedValidators[_validator], "Already a validator");
        authorizedValidators[_validator] = true;
        emit ValidatorAdded(_validator, block.timestamp);
    }

    function removeValidator(address _validator) external onlyAdmin {
        require(_validator != admin, "Cannot remove admin from validators");
        authorizedValidators[_validator] = false;
        emit ValidatorRemoved(_validator);
    }

    // ===================== COURSE MANAGEMENT =====================

    function createCourse(
        string memory _courseName,
        string memory _courseCode,
        string memory _instructor,
        uint256 _maxCapacity,
        uint256 _creditHours,
        uint256 _registrationFee
    ) external onlyValidator returns (uint256) {
        if (bytes(_courseName).length == 0) revert InvalidInput("Course name cannot be empty");
        if (bytes(_courseCode).length == 0) revert InvalidInput("Course code cannot be empty");
        if (bytes(_instructor).length == 0) revert InvalidInput("Instructor cannot be empty");
        if (_maxCapacity == 0)              revert InvalidInput("Max capacity must be > 0");
        if (_creditHours == 0 || _creditHours > 6) revert InvalidInput("Credit hours must be 1 to 6");

        uint256 courseId = courseCounter++;

        courses[courseId] = Course({
            courseId          : courseId,
            courseName        : _courseName,
            courseCode        : _courseCode,
            instructor        : _instructor,
            maxCapacity       : _maxCapacity,
            currentEnrollment : 0,
            waitlistCount     : 0,
            creditHours       : _creditHours,
            status            : CourseStatus.Active,
            registrationFee   : _registrationFee,
            exists            : true
        });

        emit CourseCreated(courseId, _courseCode, _courseName, _maxCapacity);
        return courseId;
    }

    function updateCourseCapacity(
        uint256 _courseId,
        uint256 _newCapacity
    ) external onlyAdmin courseExists(_courseId) {
        Course storage c = courses[_courseId];
        // LOGICAL FIX: cannot shrink capacity below current enrollment
        if (_newCapacity < c.currentEnrollment)
            revert InvalidInput("New capacity cannot be less than current enrollment");
        uint256 old = c.maxCapacity;
        c.maxCapacity = _newCapacity;
        emit CourseCapacityUpdated(_courseId, old, _newCapacity);
    }

    function setCourseStatus(
        uint256 _courseId,
        CourseStatus _newStatus
    ) external onlyAdmin courseExists(_courseId) {
        // LOGICAL FIX: cannot deactivate a course that has enrolled students
        if (_newStatus != CourseStatus.Active) {
            require(
                courses[_courseId].currentEnrollment == 0,
                "Cannot deactivate: students still enrolled"
            );
        }
        courses[_courseId].status = _newStatus;
        emit CourseStatusChanged(_courseId, _newStatus);
    }

    // ===================== STUDENT REGISTRATION =====================

    function registerStudent(
        string memory _name,
        string memory _email
    ) external returns (uint256) {
        // LOGICAL FIX: one wallet = one student account only
        require(walletToStudentId[msg.sender] == 0,
            "This wallet already has a registered student account");
        if (bytes(_name).length == 0)  revert InvalidInput("Name cannot be empty");
        if (bytes(_email).length == 0) revert InvalidInput("Email cannot be empty");

        uint256 studentId = studentCounter++;

        students[studentId] = Student({
            studentId       : studentId,
            name            : _name,
            email           : _email,
            status          : StudentStatus.Active,
            registeredAt    : block.timestamp,
            enrolledCourses : new uint256[](0),
            exists          : true
        });

        walletToStudentId[msg.sender] = studentId;
        emit StudentRegistered(studentId, _name, msg.sender, block.timestamp);
        return studentId;
    }

    // ===================== ENROLLMENT =====================

    /**
     * @notice Student self-enrolls. Payable — collects fee if set.
     *         If course full → auto waitlist (FIFO).
     *         Prevents: double-enroll, double-waitlist, enrollment while suspended.
     */
    function enrollCourse(uint256 _courseId)
        external payable
        courseExists(_courseId)
        courseActive(_courseId)
    {
        uint256 studentId = walletToStudentId[msg.sender];
        if (studentId == 0)
            revert InvalidInput("Please register as a student first");
        if (students[studentId].status == StudentStatus.Suspended)
            revert StudentSuspended(studentId);

        Course storage c = courses[_courseId];

        // LOGICAL FIX: fee validation
        if (msg.value < c.registrationFee)
            revert InsufficientFee(msg.value, c.registrationFee);

        RegistrationStatus current = enrollmentStatus[studentId][_courseId];

        // LOGICAL FIX: prevent double enrollment
        if (current == RegistrationStatus.Enrolled)
            revert AlreadyEnrolled(studentId, _courseId);

        // LOGICAL FIX: prevent double waitlisting
        if (current == RegistrationStatus.Waitlisted)
            revert InvalidInput("Already on the waitlist for this course");

        // Collect fee into withdrawal mapping (pull payment)
        if (msg.value > 0) {
            totalFeesCollected += msg.value;
            pendingWithdrawals[admin] += msg.value;
        }

        // Enforce capacity — enroll or waitlist
        if (c.currentEnrollment >= c.maxCapacity) {
            _addToWaitlist(studentId, _courseId);
        } else {
            _enroll(studentId, _courseId, c);
        }
    }

    /**
     * @notice Admin/validator manually enrolls a specific student
     *         Used for manual registration during add/drop period
     */
    function adminEnrollStudent(
        uint256 _studentId,
        uint256 _courseId
    ) external onlyValidator
        studentExists(_studentId)
        courseExists(_courseId)
        courseActive(_courseId)
        studentActive(_studentId)
    {
        RegistrationStatus current = enrollmentStatus[_studentId][_courseId];
        if (current == RegistrationStatus.Enrolled)
            revert AlreadyEnrolled(_studentId, _courseId);

        Course storage c = courses[_courseId];
        // LOGICAL FIX: even admin cannot exceed capacity
        if (c.currentEnrollment >= c.maxCapacity)
            revert CourseAtCapacity(_courseId, c.maxCapacity);

        _enroll(_studentId, _courseId, c);
    }

    /**
     * @notice Student drops a course they are currently enrolled in
     */
    function dropCourse(uint256 _courseId, string memory _reason)
        external
        courseExists(_courseId)
    {
        uint256 studentId = walletToStudentId[msg.sender];
        if (studentId == 0) revert InvalidInput("You are not a registered student");

        // LOGICAL FIX: student must actually be ENROLLED (not just registered or waitlisted)
        if (enrollmentStatus[studentId][_courseId] != RegistrationStatus.Enrolled)
            revert NotEnrolled(studentId, _courseId);

        _drop(studentId, _courseId, _reason);
        _promoteFromWaitlist(_courseId); // auto-promote next waitlisted student
    }

    /**
     * @notice Admin/validator removes a student from a course
     */
    function adminDropStudent(
        uint256 _studentId,
        uint256 _courseId,
        string memory _reason
    ) external onlyValidator
        studentExists(_studentId)
        courseExists(_courseId)
    {
        if (enrollmentStatus[_studentId][_courseId] != RegistrationStatus.Enrolled)
            revert NotEnrolled(_studentId, _courseId);

        _drop(_studentId, _courseId, _reason);
        _promoteFromWaitlist(_courseId);
    }

    // ===================== PRIVATE HELPER FUNCTIONS =====================

    function _enroll(
        uint256 _studentId,
        uint256 _courseId,
        Course storage _course
    ) private {
        enrollmentStatus[_studentId][_courseId] = RegistrationStatus.Enrolled;
        _course.currentEnrollment++;
        students[_studentId].enrolledCourses.push(_courseId);
        courseStudents[_courseId].push(_studentId);
        _createRecord(_studentId, _courseId, RegistrationStatus.Enrolled, "ENROLLED");
        emit StudentEnrolled(_studentId, _courseId, block.timestamp, msg.sender);
    }

    function _drop(
        uint256 _studentId,
        uint256 _courseId,
        string memory _reason
    ) private {
        enrollmentStatus[_studentId][_courseId] = RegistrationStatus.Dropped;
        courses[_courseId].currentEnrollment--;
        _removeFromUintArray(courseStudents[_courseId], _studentId);
        _removeFromUintArray(students[_studentId].enrolledCourses, _courseId);
        _createRecord(_studentId, _courseId, RegistrationStatus.Dropped, "DROPPED");
        emit StudentDropped(_studentId, _courseId, block.timestamp, _reason);
    }

    function _addToWaitlist(uint256 _studentId, uint256 _courseId) private {
        enrollmentStatus[_studentId][_courseId] = RegistrationStatus.Waitlisted;
        courseWaitlist[_courseId].push(_studentId);
        courses[_courseId].waitlistCount++;
        uint256 position = courseWaitlist[_courseId].length;
        _createRecord(_studentId, _courseId, RegistrationStatus.Waitlisted, "WAITLISTED");
        emit StudentWaitlisted(_studentId, _courseId, position);
    }

    /**
     * @dev FIFO waitlist: promotes the FIRST person added to the list
     *      Only promotes if a seat is actually available
     */
    function _promoteFromWaitlist(uint256 _courseId) private {
        uint256[] storage waitlist = courseWaitlist[_courseId];
        if (waitlist.length == 0) return;

        Course storage c = courses[_courseId];
        if (c.currentEnrollment >= c.maxCapacity) return; // safety check

        uint256 promotedStudentId = waitlist[0];

        // LOGICAL FIX: shift array left to maintain FIFO order
        for (uint256 i = 0; i < waitlist.length - 1; i++) {
            waitlist[i] = waitlist[i + 1];
        }
        waitlist.pop();
        c.waitlistCount--;

        // Enroll the promoted student
        _enroll(promotedStudentId, _courseId, c);
        emit WaitlistPromoted(promotedStudentId, _courseId, block.timestamp);
    }

    /**
     * @dev Removes a value from a uint256 array (swap with last element + pop)
     *      O(n) search, O(1) removal — gas efficient
     */
    function _removeFromUintArray(uint256[] storage arr, uint256 value) private {
        uint256 len = arr.length;
        for (uint256 i = 0; i < len; i++) {
            if (arr[i] == value) {
                arr[i] = arr[len - 1]; // overwrite with last element
                arr.pop();             // remove last (now duplicate)
                return;
            }
        }
        // value not found — no-op (safe)
    }

    function _createRecord(
        uint256 _studentId,
        uint256 _courseId,
        RegistrationStatus _status,
        string memory _action
    ) private returns (uint256) {
        uint256 rid = recordCounter++;
        records[rid] = RegistrationRecord({
            recordId   : rid,
            studentId  : _studentId,
            courseId   : _courseId,
            status     : _status,
            timestamp  : block.timestamp,
            recordedBy : msg.sender,
            action     : _action
        });
        return rid;
    }

    // ===================== WITHDRAWAL PATTERN =====================

    /**
     * @notice Secure ether withdrawal (pull payment pattern)
     *         Prevents reentrancy by zeroing balance before transfer
     */
    function withdraw() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No fees available to withdraw");
        pendingWithdrawals[msg.sender] = 0; // zero BEFORE transfer — reentrancy protection
        payable(msg.sender).transfer(amount);
        emit FeeWithdrawn(msg.sender, amount);
    }

    function getPendingWithdrawal(address _addr) external view returns (uint256) {
        return pendingWithdrawals[_addr];
    }

    // ===================== VIEW FUNCTIONS =====================

    function getStudent(uint256 _studentId)
        external view studentExists(_studentId)
        returns (
            string memory name,
            string memory email,
            StudentStatus status,
            uint256 registeredAt,
            uint256[] memory enrolledCourses
        )
    {
        Student storage s = students[_studentId];
        return (s.name, s.email, s.status, s.registeredAt, s.enrolledCourses);
    }

    function getCourse(uint256 _courseId)
        external view courseExists(_courseId)
        returns (
            string memory courseName,
            string memory courseCode,
            string memory instructor,
            uint256 maxCapacity,
            uint256 currentEnrollment,
            uint256 waitlistCount,
            CourseStatus status,
            uint256 registrationFee
        )
    {
        Course storage c = courses[_courseId];
        return (
            c.courseName, c.courseCode, c.instructor,
            c.maxCapacity, c.currentEnrollment, c.waitlistCount,
            c.status, c.registrationFee
        );
    }

    function getMyStudentId() external view returns (uint256) {
        return walletToStudentId[msg.sender];
    }

    function getEnrollmentStatus(uint256 _studentId, uint256 _courseId)
        external view returns (RegistrationStatus)
    {
        return enrollmentStatus[_studentId][_courseId];
    }

    function getCourseStudents(uint256 _courseId)
        external view courseExists(_courseId)
        returns (uint256[] memory)
    {
        return courseStudents[_courseId];
    }

    function getCourseWaitlist(uint256 _courseId)
        external view courseExists(_courseId)
        returns (uint256[] memory)
    {
        return courseWaitlist[_courseId];
    }

    function getAvailableSeats(uint256 _courseId)
        external view courseExists(_courseId)
        returns (uint256)
    {
        Course storage c = courses[_courseId];
        if (c.currentEnrollment >= c.maxCapacity) return 0;
        return c.maxCapacity - c.currentEnrollment;
    }

    function getTotalCourses()  external view returns (uint256) { return courseCounter  - 100; }
    function getTotalStudents() external view returns (uint256) { return studentCounter - 1000; }
    function getTotalRecords()  external view returns (uint256) { return recordCounter  - 1; }
    function isAdmin(address _a) external view returns (bool)   { return _a == admin; }
    function isValidator(address _a) external view returns (bool) {
        return authorizedValidators[_a] || _a == admin;
    }

    // ===================== PURE FUNCTION =====================

    /// @notice Stateless calculation — demonstrates pure function
    function calculateFillPercentage(uint256 enrolled, uint256 maxCapacity)
        external pure returns (uint256)
    {
        if (maxCapacity == 0) return 0;
        return (enrolled * 100) / maxCapacity;
    }

    // ===================== OVERLOADED FUNCTIONS =====================

    /// @notice Suspend student by their student ID
    function suspendStudent(uint256 _studentId)
        external onlyAdmin studentExists(_studentId)
    {
        require(students[_studentId].status != StudentStatus.Suspended,
            "Student is already suspended");
        students[_studentId].status = StudentStatus.Suspended;
    }

    /// @notice Suspend student by their wallet address (overloaded version)
    function suspendStudent(address _wallet) external onlyAdmin {
        uint256 sid = walletToStudentId[_wallet];
        require(sid != 0, "No student found for this wallet address");
        require(students[sid].status != StudentStatus.Suspended,
            "Student is already suspended");
        students[sid].status = StudentStatus.Suspended;
    }

    // ===================== FALLBACK & RECEIVE =====================

    /// @notice Fallback — rejects any unexpected calls with ETH
    fallback() external payable {
        revert("Unexpected call. Use enrollCourse() to send ETH.");
    }

    /// @notice Receive — rejects plain ETH transfers
    receive() external payable {
        revert("Direct ETH transfers rejected. Use enrollCourse().");
    }
}
