// SPDX-License-Identifier: MIT
// Specifies the license under which the code is released. MIT is a permissive license.
pragma solidity ^0.8.20;
// Declares the Solidity compiler version to be used.
// The caret (^) means compatible with versions from 0.8.20 up to (but not including) 0.9.0.

contract DeadManSwitch {
    // Defines the smart contract named DeadManSwitch.

    address public owner;
    // Declares a public state variable 'owner' of type 'address'.
    // 'public' automatically creates a getter function to read its value.
    // This address will be the primary controller of the switch.

    address public heir;
    // Declares a public state variable 'heir' of type 'address'.
    // This is the primary recipient of funds if the switch is triggered.

    uint256 public lastCheckIn;
    // Declares a public state variable 'lastCheckIn' of type 'uint256'.
    // Stores the timestamp of the last successful check-in by the owner.

    uint256 public checkInInterval;
    // Declares a public state variable 'checkInInterval' of type 'uint256'.
    // The time duration (in seconds) within which the owner must check in.

    uint256 public gracePeriod;
    // Declares a public state variable 'gracePeriod' of type 'uint256'.
    // An additional time duration (in seconds) after the check-in interval expires,
    // before the switch can be triggered.

    bool public isPaused;
    // Declares a public state variable 'isPaused' of type 'bool'.
    // Indicates whether the contract's functionality (like check-ins or triggers) is temporarily paused.

    // Enhanced features
    address[] public backupHeirs;
    // Declares a public dynamic array 'backupHeirs' to store multiple backup heir addresses.

    mapping(address => bool) public authorizedUsers;
    // Declares a public mapping to keep track of addresses that are authorized to perform certain actions.
    // Maps an address to a boolean indicating if they are authorized.

    uint256 public checkInStreak;
    // Declares a public state variable 'checkInStreak' of type 'uint256'.
    // Tracks consecutive successful check-ins without missing an interval.

    uint256 public totalCheckIns;
    // Declares a public state variable 'totalCheckIns' of type 'uint256'.
    // Records the total number of check-ins ever performed.

    // Events tracking
    struct CheckInEvent {
        // Defines a struct to store details of a check-in event.
        uint256 timestamp;
        // Timestamp of the check-in.
        address by;
        // Address that performed the check-in.
        uint256 streakCount;
        // Check-in streak count at the time of check-in.
    }

    struct HeirChangeEvent {
        // Defines a struct to store details of an heir change event.
        uint256 timestamp;
        // Timestamp of the heir change.
        address previousHeir;
        // The heir's address before the change.
        address newHeir;
        // The new heir's address.
        address changedBy;
        // Address that changed the heir.
    }

    CheckInEvent[] public checkInHistory;
    // Declares a public dynamic array to store a history of all check-in events.

    HeirChangeEvent[] public heirChangeHistory;
    // Declares a public dynamic array to store a history of all heir change events.

    // Gas estimation tracking
    mapping(string => uint256) public avgGasUsed;
    // Mapping to store the sum of gas used for each function, indexed by function name.

    mapping(string => uint256) public gasCallCount;
    // Mapping to store the number of times each function has been called, indexed by function name.

    error NotOwner();
    // Custom error defined for when an action can only be performed by the owner.

    error NotAuthorized();
    // Custom error defined for when an action requires authorization.

    error ZeroAddress();
    // Custom error defined for when a zero address (0x0) is provided where a valid address is required.

    error SwitchPaused();
    // Custom error defined for when an action is attempted while the switch is paused.

    error OwnerStillAlive();
    // Custom error defined for when a trigger attempt is made while the owner is considered "alive".

    error InsufficientBalance();
    // Custom error defined for when there isn't enough Ether in the contract for a withdrawal.

    error TransferFailed();
    // Custom error defined for when an Ether transfer operation fails.

    error InvalidInterval();
    // Custom error defined for when an invalid check-in interval (e.g., zero) is provided.

    error InvalidGracePeriod();
    // Custom error defined for when an invalid grace period (e.g., too long) is provided.

    error MaxBackupHeirsReached();
    // Custom error defined for when trying to add more backup heirs than allowed.

    error HeirNotFound();
    // Custom error defined for when trying to remove a backup heir that doesn't exist.

    event CheckedIn(address indexed owner, uint256 timestamp, uint256 streak);
    // Event emitted when the owner successfully checks in.

    event HeirChanged(address indexed previousHeir, address indexed newHeir, address indexed changedBy);
    // Event emitted when the heir address is changed.

    event BackupHeirAdded(address indexed heir);
    // Event emitted when a backup heir is added.

    event BackupHeirRemoved(address indexed heir);
    // Event emitted when a backup heir is removed.

    event Triggered(address indexed by, uint256 timestamp, uint256 amount);
    // Event emitted when the Dead Man Switch is triggered and funds are sent.

    event Withdrawn(address indexed to, uint256 amount);
    // Event emitted when funds are withdrawn from the contract.

    event Paused();
    // Event emitted when the contract is paused.

    event Resumed();
    // Event emitted when the contract is resumed.

    event IntervalChanged(uint256 newInterval);
    // Event emitted when the check-in interval is changed.

    event GracePeriodChanged(uint256 newGracePeriod);
    // Event emitted when the grace period is changed.

    event AuthorizedUserAdded(address indexed user);
    // Event emitted when a user is added to the authorized list.

    event AuthorizedUserRemoved(address indexed user);
    // Event emitted when a user is removed from the authorized list.

    event EmergencyOwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    // Event emitted when emergency ownership transfer occurs.

    constructor(address _heir, uint256 _intervalInDays, uint256 _gracePeriodInHours) payable {
        // The constructor runs only once when the contract is deployed.
        // It accepts initial heir, check-in interval, and grace period.
        // 'payable' allows the constructor to receive Ether upon deployment.

        if (_heir == address(0)) revert ZeroAddress();
        // Reverts if the provided heir address is the zero address.

        if (_intervalInDays == 0) revert InvalidInterval();
        // Reverts if the check-in interval is set to zero days.

        if (_gracePeriodInHours > 24 * 7) revert InvalidGracePeriod();
        // Reverts if the grace period exceeds 7 days (24 hours * 7 days).

        owner = msg.sender;
        // Sets the deployer of the contract as the owner.

        heir = _heir;
        // Sets the primary heir provided in the constructor.

        checkInInterval = _intervalInDays * 1 days;
        // Converts days to seconds and sets the check-in interval.
        // '1 days' is a time unit literal in Solidity, representing 24 * 60 * 60 seconds.

        gracePeriod = _gracePeriodInHours * 1 hours;
        // Converts hours to seconds and sets the grace period.
        // '1 hours' is a time unit literal in Solidity, representing 60 * 60 seconds.

        lastCheckIn = block.timestamp;
        // Sets the initial last check-in time to the current block's timestamp.

        authorizedUsers[msg.sender] = true;
        // Authorizes the contract deployer (owner).

        authorizedUsers[_heir] = true;
        // Authorizes the initial heir.
    }

    modifier onlyOwner() {
        // Defines a modifier named 'onlyOwner'.
        // Modifiers are used to DRY (Don't Repeat Yourself) code and add checks before a function executes.
        if (msg.sender != owner) revert NotOwner();
        // If the caller is not the owner, the transaction reverts with a custom error.
        _;
        // The '_' symbol tells Solidity to execute the function code after the modifier's checks.
    }

    modifier onlyAuthorized() {
        // Defines a modifier named 'onlyAuthorized'.
        if (!authorizedUsers[msg.sender] && msg.sender != owner) revert NotAuthorized();
        // If the caller is not in the authorizedUsers mapping AND is not the owner, revert.
        _;
        // Execute the function code.
    }

    modifier notPaused() {
        // Defines a modifier named 'notPaused'.
        if (isPaused) revert SwitchPaused();
        // If the contract is paused, revert the transaction.
        _;
        // Execute the function code.
    }

    function checkIn() external onlyOwner notPaused {
        // Allows the owner to check in, resetting the timer.
        // 'external' means it can only be called from outside the contract.
        // 'onlyOwner' and 'notPaused' modifiers apply their checks before execution.

        uint256 gasStart = gasleft();
        // Records the amount of gas remaining at the start of the function execution.

        lastCheckIn = block.timestamp;
        // Updates the last check-in time to the current block's timestamp.

        checkInStreak++;
        // Increments the check-in streak counter.

        totalCheckIns++;
        // Increments the total check-ins counter.

        checkInHistory.push(CheckInEvent({
            // Adds a new CheckInEvent struct to the checkInHistory array.
            timestamp: block.timestamp,
            by: msg.sender,
            streakCount: checkInStreak
        }));

        emit CheckedIn(msg.sender, lastCheckIn, checkInStreak);
        // Emits the CheckedIn event, logging the owner, timestamp, and streak.

        _updateGasUsage("checkIn", gasStart);
        // Calls an internal helper function to track gas usage for this function.
    }

    function setHeir(address _newHeir) external onlyOwner {
        // Allows the owner to change the primary heir.

        if (_newHeir == address(0)) revert ZeroAddress();
        // Reverts if the new heir address is the zero address.

        address previousHeir = heir;
        // Stores the current heir's address before changing it.

        heir = _newHeir;
        // Updates the primary heir to the new address.

        // Update authorization
        authorizedUsers[previousHeir] = false;
        // De-authorizes the previous heir.

        authorizedUsers[_newHeir] = true;
        // Authorizes the new heir.

        heirChangeHistory.push(HeirChangeEvent({
            // Adds a new HeirChangeEvent struct to the heirChangeHistory array.
            timestamp: block.timestamp,
            previousHeir: previousHeir,
            newHeir: _newHeir,
            changedBy: msg.sender
        }));

        emit HeirChanged(previousHeir, _newHeir, msg.sender);
        // Emits the HeirChanged event, logging the previous heir, new heir, and caller.
    }

    function addBackupHeir(address _backupHeir) external onlyOwner {
        // Allows the owner to add a backup heir.

        if (_backupHeir == address(0)) revert ZeroAddress();
        // Reverts if the backup heir address is the zero address.

        if (backupHeirs.length >= 5) revert MaxBackupHeirsReached();
        // Reverts if the maximum number of backup heirs (5) has been reached.

        backupHeirs.push(_backupHeir);
        // Adds the new backup heir to the backupHeirs array.

        authorizedUsers[_backupHeir] = true;
        // Authorizes the new backup heir.

        emit BackupHeirAdded(_backupHeir);
        // Emits the BackupHeirAdded event.
    }

    function removeBackupHeir(address _backupHeir) external onlyOwner {
        // Allows the owner to remove a backup heir.

        for (uint256 i = 0; i < backupHeirs.length; i++) {
            // Loops through the backupHeirs array.
            if (backupHeirs[i] == _backupHeir) {
                // If the current backup heir matches the one to be removed.
                backupHeirs[i] = backupHeirs[backupHeirs.length - 1];
                // Swaps the found heir with the last element in the array.
                backupHeirs.pop();
                // Removes the last element (which is now the one to be removed).
                authorizedUsers[_backupHeir] = false;
                // De-authorizes the removed backup heir.
                emit BackupHeirRemoved(_backupHeir);
                // Emits the BackupHeirRemoved event.
                return;
                // Exits the function after removal.
            }
        }
        revert HeirNotFound();
        // If the loop finishes without finding the heir, revert.
    }

    function setCheckInInterval(uint256 _intervalInDays) external onlyOwner {
        // Allows the owner to change the check-in interval.

        if (_intervalInDays == 0) revert InvalidInterval();
        // Reverts if the new interval is zero days.

        checkInInterval = _intervalInDays * 1 days;
        // Updates the check-in interval.

        emit IntervalChanged(checkInInterval);
        // Emits the IntervalChanged event.
    }

    function setGracePeriod(uint256 _gracePeriodInHours) external onlyOwner {
        // Allows the owner to change the grace period.

        if (_gracePeriodInHours > 24 * 7) revert InvalidGracePeriod();
        // Reverts if the new grace period exceeds 7 days.

        gracePeriod = _gracePeriodInHours * 1 hours;
        // Updates the grace period.

        emit GracePeriodChanged(gracePeriod);
        // Emits the GracePeriodChanged event.
    }

    function isOwnerAlive() public view returns (bool) {
        // Checks if the owner is currently considered "alive" based on check-ins.
        // 'public' allows external and internal calls. 'view' means it doesn't modify state.

        return block.timestamp <= lastCheckIn + checkInInterval + gracePeriod;
        // Returns true if the current time is within the last check-in plus interval and grace period.
    }

    function getTimeUntilDanger() public view returns (uint256) {
        // Calculates the time remaining until the owner enters the "danger" period (interval expires).

        uint256 dangerTime = lastCheckIn + checkInInterval;
        // Calculates the timestamp when the check-in interval expires.

        return block.timestamp >= dangerTime ? 0 : dangerTime - block.timestamp;
        // If current time is past dangerTime, return 0; otherwise, return time remaining.
    }

    function getTimeUntilTrigger() public view returns (uint256) {
        // Calculates the time remaining until the switch can be triggered (interval + grace period expires).

        uint256 triggerTime = lastCheckIn + checkInInterval + gracePeriod;
        // Calculates the timestamp when the grace period expires.

        return block.timestamp >= triggerTime ? 0 : triggerTime - block.timestamp;
        // If current time is past triggerTime, return 0; otherwise, return time remaining.
    }

    function triggerSwitch() external notPaused {
        // Triggers the Dead Man Switch, sending funds to the heir(s).
        // 'notPaused' modifier ensures the switch isn't paused.

        uint256 gasStart = gasleft();
        // Records gas remaining for gas usage tracking.

        if (isOwnerAlive()) revert OwnerStillAlive();
        // Reverts if the owner is still considered "alive".

        uint256 balance = address(this).balance;
        // Gets the current Ether balance of the contract.

        if (balance == 0) return;
        // If the contract has no Ether, exit the function.

        emit Triggered(msg.sender, block.timestamp, balance);
        // Emits the Triggered event before attempting to send funds.

        // Try primary heir first
        (bool success, ) = payable(heir).call{value: balance}("");
        // Attempts to send all contract balance to the primary heir using a low-level call.
        // This is a robust way to send Ether and handle potential recipient contract logic.

        if (!success) {
            // If the transfer to the primary heir failed.
            // Try backup heirs
            for (uint256 i = 0; i < backupHeirs.length; i++) {
                // Loops through backup heirs.
                (bool backupSuccess, ) = payable(backupHeirs[i]).call{value: balance}("");
                // Attempts to send all contract balance to the current backup heir.
                if (backupSuccess) {
                    // If transfer to a backup heir succeeds, stop trying others.
                    break;
                }
            }
        }

        _updateGasUsage("triggerSwitch", gasStart);
        // Updates gas usage statistics for this function.
    }

    function withdraw(uint256 amount) external onlyOwner {
        // Allows the owner to withdraw a specified amount of Ether from the contract.

        if (amount > address(this).balance) revert InsufficientBalance();
        // Reverts if the requested amount is more than the contract's balance.

        emit Withdrawn(owner, amount);
        // Emits the Withdrawn event before the transfer.

        (bool success, ) = payable(owner).call{value: amount}("");
        // Attempts to send the specified amount to the owner.

        if (!success) revert TransferFailed();
        // Reverts if the Ether transfer fails.
    }

    function batchWithdraw(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner {
        // Allows the owner to withdraw and distribute Ether to multiple recipients in a single transaction.
        // 'calldata' is used for external function parameters that are read-only and not stored.

        require(recipients.length == amounts.length, "Arrays length mismatch");
        // Ensures that the number of recipients matches the number of amounts.

        uint256 totalAmount = 0;
        // Initializes a variable to sum up the total withdrawal amount.

        for (uint256 i = 0; i < amounts.length; i++) {
            // Loops through the amounts array.
            totalAmount += amounts[i];
            // Adds each amount to the total.
        }

        if (totalAmount > address(this).balance) revert InsufficientBalance();
        // Reverts if the total requested withdrawal exceeds the contract's balance.

        for (uint256 i = 0; i < recipients.length; i++) {
            // Loops through the recipients and amounts.
            (bool success, ) = payable(recipients[i]).call{value: amounts[i]}("");
            // Sends the corresponding amount to each recipient.
            if (!success) revert TransferFailed();
            // Reverts if any individual transfer fails, ensuring atomicity (all or nothing).
            emit Withdrawn(recipients[i], amounts[i]);
            // Emits a Withdrawn event for each successful transfer.
        }
    }

    function pauseSwitch() external onlyOwner {
        // Allows the owner to pause the switch's check-in and trigger functionality.

        isPaused = true;
        // Sets the 'isPaused' flag to true.

        emit Paused();
        // Emits the Paused event.
    }

    function resumeSwitch() external onlyOwner {
        // Allows the owner to resume the switch's functionality after it was paused.

        isPaused = false;
        // Sets the 'isPaused' flag to false.

        emit Resumed();
        // Emits the Resumed event.
    }

    function emergencyChangeOwner(address _newOwner) external {
        // Allows the heir to take over ownership if the owner is deemed "dead".
        // This is a safety mechanism in case the original owner loses their key and the heir needs to manage the contract.

        if (msg.sender != heir) revert NotOwner();
        // Only the designated heir can call this function.

        if (isOwnerAlive()) revert OwnerStillAlive();
        // Reverts if the original owner is still considered "alive".

        if (_newOwner == address(0)) revert ZeroAddress();
        // Reverts if the new owner address is the zero address.

        address previousOwner = owner;
        // Stores the current owner's address.

        owner = _newOwner;
        // Transfers ownership to the new address.

        lastCheckIn = block.timestamp;
        // Resets the last check-in time to the current block's timestamp for the new owner.

        checkInStreak = 0; // Reset streak
        // Resets the check-in streak as ownership has changed.

        // Update authorization
        authorizedUsers[previousOwner] = false;
        // De-authorizes the previous owner.

        authorizedUsers[_newOwner] = true;
        // Authorizes the new owner.

        emit EmergencyOwnershipTransferred(previousOwner, _newOwner);
        // Emits the EmergencyOwnershipTransferred event.
    }

    function checkInAndSetHeir(address _newHeir) external onlyOwner notPaused {
        // A combined function to check in and optionally update the heir in one transaction.

        if (_newHeir == address(0)) revert ZeroAddress();
        // Reverts if the new heir address is the zero address.

        lastCheckIn = block.timestamp;
        // Updates the last check-in time.

        checkInStreak++;
        // Increments the check-in streak.

        totalCheckIns++;
        // Increments the total check-ins.

        checkInHistory.push(CheckInEvent({
            // Adds a new check-in event to the history.
            timestamp: block.timestamp,
            by: msg.sender,
            streakCount: checkInStreak
        }));

        emit CheckedIn(msg.sender, lastCheckIn, checkInStreak);
        // Emits the CheckedIn event.

        if (_newHeir != heir) {
            // Only update if the new heir is different from the current one to save gas.
            address previousHeir = heir;
            // Stores the current heir.
            heir = _newHeir;
            // Updates the heir.

            authorizedUsers[previousHeir] = false;
            // De-authorizes the previous heir.

            authorizedUsers[_newHeir] = true;
            // Authorizes the new heir.

            heirChangeHistory.push(HeirChangeEvent({
                // Adds a new heir change event to the history.
                timestamp: block.timestamp,
                previousHeir: previousHeir,
                newHeir: _newHeir,
                changedBy: msg.sender
            }));

            emit HeirChanged(previousHeir, _newHeir, msg.sender);
            // Emits the HeirChanged event.
        }
    }

    function getContractDetails() external view returns (
        // Provides a comprehensive view of the contract's main details.
        // 'view' means it doesn't modify state and doesn't cost gas (except for transaction fees to read from network).
        address _owner,
        address _heir,
        uint256 _lastCheckIn,
        uint256 _checkInInterval,
        uint256 _gracePeriod,
        uint256 _timeUntilDanger,
        uint256 _timeUntilTrigger,
        bool _paused,
        uint256 _balance,
        uint256 _checkInStreak,
        uint256 _totalCheckIns
    ) {
        // Defines the return types for the function.
        _owner = owner;
        _heir = heir;
        _lastCheckIn = lastCheckIn;
        _checkInInterval = checkInInterval;
        _gracePeriod = gracePeriod;
        _timeUntilDanger = getTimeUntilDanger();
        // Calls the internal getTimeUntilDanger() function.
        _timeUntilTrigger = getTimeUntilTrigger();
        // Calls the internal getTimeUntilTrigger() function.
        _paused = isPaused;
        _balance = address(this).balance;
        // Gets the current balance of the contract.
        _checkInStreak = checkInStreak;
        _totalCheckIns = totalCheckIns;
    }

    function getBackupHeirs() external view returns (address[] memory) {
        // Returns the list of all backup heirs.
        // 'memory' specifies that the array is stored in memory, not storage.
        return backupHeirs;
    }

    function getCheckInHistory(uint256 limit) external view returns (CheckInEvent[] memory) {
        // Returns a limited number of the most recent check-in events.

        uint256 length = checkInHistory.length;
        // Gets the total number of check-in events.

        if (limit > length) limit = length;
        // Adjusts the limit if it's greater than the available history.

        CheckInEvent[] memory recent = new CheckInEvent[](limit);
        // Creates a new array in memory to hold the recent events.

        for (uint252 i = 0; i < limit; i++) {
            // Loops to populate the 'recent' array.
            recent[i] = checkInHistory[length - 1 - i];
            // Copies events from the end of the history array (most recent first).
        }
        return recent;
        // Returns the array of recent check-in events.
    }

    function getHeirChangeHistory(uint256 limit) external view returns (HeirChangeEvent[] memory) {
        // Returns a limited number of the most recent heir change events.

        uint256 length = heirChangeHistory.length;
        // Gets the total number of heir change events.

        if (limit > length) limit = length;
        // Adjusts the limit if it's greater than the available history.

        HeirChangeEvent[] memory recent = new HeirChangeEvent[](limit);
        // Creates a new array in memory for recent events.

        for (uint252 i = 0; i < limit; i++) {
            // Loops to populate the 'recent' array.
            recent[i] = heirChangeHistory[length - 1 - i];
            // Copies events from the end of the history array (most recent first).
        }
        return recent;
        // Returns the array of recent heir change events.
    }

    function getHealthScore() external view returns (uint256) {
        // Calculates and returns a "health score" for the contract based on various factors.

        if (totalCheckIns == 0) return 0;
        // If no check-ins have occurred, the score is 0.

        uint256 consistencyScore = (checkInStreak * 100) / totalCheckIns;
        // Calculates a score based on the check-in streak vs. total check-ins.

        uint256 timeScore = isOwnerAlive() ? 100 : 0;
        // Gives 100 if the owner is alive, 0 otherwise.

        uint256 balanceScore = address(this).balance > 0 ? 100 : 0;
        // Gives 100 if the contract has balance, 0 otherwise.

        return (consistencyScore + timeScore + balanceScore) / 3;
        // Returns the average of the three scores.
    }

    function estimateGas(string calldata functionName) external view returns (uint256) {
        // Provides an estimated average gas usage for a given function.
        // This is based on previous calls to the function within this contract.

        uint256 calls = gasCallCount[functionName];
        // Gets the number of times the function has been called.

        if (calls == 0) return 0;
        // If the function hasn't been called, return 0.

        return avgGasUsed[functionName] / calls;
        // Returns the average gas used (total gas / total calls).
    }

    function _updateGasUsage(string memory functionName, uint256 gasStart) internal {
        // Internal helper function to track gas usage for other functions.
        // 'internal' means it can only be called from within this contract or derived contracts.

        uint256 gasUsed = gasStart - gasleft();
        // Calculates the gas consumed by the calling function.

        avgGasUsed[functionName] += gasUsed;
        // Adds the gas used to the total gas for that function.

        gasCallCount[functionName]++;
        // Increments the call count for that function.
    }

    function canBTriggered() external view returns (bool) {
        // Checks if the contract can currently be triggered.

        return !isPaused && !isOwnerAlive();
        // Returns true if the switch is NOT paused AND the owner is NOT alive.
    }

    receive() external payable {}
    // This special function is executed whenever the contract receives plain Ether
    // without any function call data. It must be 'external' and 'payable'.
}
