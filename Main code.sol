// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract DeadManSwitchFactory {
    event ContractDeployed(address indexed deployer, address indexed contractAddress, address indexed heir);
    
    struct DeployedContract {
        address contractAddress;
        address owner;
        address heir;
        uint256 deployedAt;
        bool isActive;
    }
    
    mapping(address => address[]) public userContracts;
    mapping(address => DeployedContract) public deployedContracts;
    address[] public allContracts;
    
    function deployDeadManSwitch(
        address _heir,
        uint256 _intervalInDays,
        uint256 _gracePeriodInHours
    ) external payable returns (address) {
        DeadManSwitch newContract = new DeadManSwitch{value: msg.value}(
            _heir,
            _intervalInDays,
            _gracePeriodInHours
        );
        
        address contractAddress = address(newContract);
        
        userContracts[msg.sender].push(contractAddress);
        deployedContracts[contractAddress] = DeployedContract({
            contractAddress: contractAddress,
            owner: msg.sender,
            heir: _heir,
            deployedAt: block.timestamp,
            isActive: true
        });
        allContracts.push(contractAddress);
        
        emit ContractDeployed(msg.sender, contractAddress, _heir);
        return contractAddress;
    }
    
    function getUserContracts(address user) external view returns (address[] memory) {
        return userContracts[user];
    }
    
    function getContractInfo(address contractAddress) external view returns (DeployedContract memory) {
        return deployedContracts[contractAddress];
    }
    
    function getAllContracts() external view returns (address[] memory) {
        return allContracts;
    }
}

contract DeadManSwitch {
    
    address public owner;          
    address public heir;          
    uint256 public lastCheckIn;       
    uint256 public checkInInterval;   
    uint256 public gracePeriod;      
    bool public isPaused;
    
    // Enhanced features
    address[] public backupHeirs;
    mapping(address => bool) public authorizedUsers;
    uint256 public checkInStreak;
    uint256 public totalCheckIns;
    
    // Events tracking
    struct CheckInEvent {
        uint256 timestamp;
        address by;
        uint256 streakCount;
    }
    
    struct HeirChangeEvent {
        uint256 timestamp;
        address previousHeir;
        address newHeir;
        address changedBy;
    }
    
    CheckInEvent[] public checkInHistory;
    HeirChangeEvent[] public heirChangeHistory;
    
    // Gas estimation tracking
    mapping(string => uint256) public avgGasUsed;
    mapping(string => uint256) public gasCallCount;

    error NotOwner();
    error NotAuthorized();
    error ZeroAddress();
    error SwitchPaused();
    error OwnerStillAlive();
    error InsufficientBalance();
    error TransferFailed();
    error InvalidInterval();
    error InvalidGracePeriod();
    error MaxBackupHeirsReached();
    error HeirNotFound();
    
    event CheckedIn(address indexed owner, uint256 timestamp, uint256 streak);
    event HeirChanged(address indexed previousHeir, address indexed newHeir, address indexed changedBy);
    event BackupHeirAdded(address indexed heir);
    event BackupHeirRemoved(address indexed heir);
    event Triggered(address indexed by, uint256 timestamp, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);
    event Paused();
    event Resumed();
    event IntervalChanged(uint256 newInterval);
    event GracePeriodChanged(uint256 newGracePeriod);
    event AuthorizedUserAdded(address indexed user);
    event AuthorizedUserRemoved(address indexed user);
    event EmergencyOwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address _heir, uint256 _intervalInDays, uint256 _gracePeriodInHours) payable {
        if (_heir == address(0)) revert ZeroAddress();
        if (_intervalInDays == 0) revert InvalidInterval();
        if (_gracePeriodInHours > 24 * 7) revert InvalidGracePeriod(); // Max 7 days grace period
        
        owner = msg.sender;
        heir = _heir;
        checkInInterval = _intervalInDays * 1 days;
        gracePeriod = _gracePeriodInHours * 1 hours;
        lastCheckIn = block.timestamp;
        authorizedUsers[msg.sender] = true;
        authorizedUsers[_heir] = true;
    }
    
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }
    
    modifier onlyAuthorized() {
        if (!authorizedUsers[msg.sender] && msg.sender != owner) revert NotAuthorized();
        _;
    }
    
    modifier notPaused() {
        if (isPaused) revert SwitchPaused();
        _;
    }

    function checkIn() external onlyOwner notPaused {
        uint256 gasStart = gasleft();
        
        lastCheckIn = block.timestamp;
        checkInStreak++;
        totalCheckIns++;
        
        checkInHistory.push(CheckInEvent({
            timestamp: block.timestamp,
            by: msg.sender,
            streakCount: checkInStreak
        }));
        
        emit CheckedIn(msg.sender, lastCheckIn, checkInStreak);
        
        _updateGasUsage("checkIn", gasStart);
    }
    
    function setHeir(address _newHeir) external onlyOwner {
        if (_newHeir == address(0)) revert ZeroAddress();
        
        address previousHeir = heir;
        heir = _newHeir;
        
        // Update authorization
        authorizedUsers[previousHeir] = false;
        authorizedUsers[_newHeir] = true;
        
        heirChangeHistory.push(HeirChangeEvent({
            timestamp: block.timestamp,
            previousHeir: previousHeir,
            newHeir: _newHeir,
            changedBy: msg.sender
        }));
        
        emit HeirChanged(previousHeir, _newHeir, msg.sender);
    }
    
    function addBackupHeir(address _backupHeir) external onlyOwner {
        if (_backupHeir == address(0)) revert ZeroAddress();
        if (backupHeirs.length >= 5) revert MaxBackupHeirsReached();
        
        backupHeirs.push(_backupHeir);
        authorizedUsers[_backupHeir] = true;
        
        emit BackupHeirAdded(_backupHeir);
    }
    
    function removeBackupHeir(address _backupHeir) external onlyOwner {
        for (uint256 i = 0; i < backupHeirs.length; i++) {
            if (backupHeirs[i] == _backupHeir) {
                backupHeirs[i] = backupHeirs[backupHeirs.length - 1];
                backupHeirs.pop();
                authorizedUsers[_backupHeir] = false;
                emit BackupHeirRemoved(_backupHeir);
                return;
            }
        }
        revert HeirNotFound();
    }
    
    function setCheckInInterval(uint256 _intervalInDays) external onlyOwner {
        if (_intervalInDays == 0) revert InvalidInterval();
        
        checkInInterval = _intervalInDays * 1 days;
        emit IntervalChanged(checkInInterval);
    }
    
    function setGracePeriod(uint256 _gracePeriodInHours) external onlyOwner {
        if (_gracePeriodInHours > 24 * 7) revert InvalidGracePeriod();
        
        gracePeriod = _gracePeriodInHours * 1 hours;
        emit GracePeriodChanged(gracePeriod);
    }

    function isOwnerAlive() public view returns (bool) {
        return block.timestamp <= lastCheckIn + checkInInterval + gracePeriod;
    }
    
    function getTimeUntilDanger() public view returns (uint256) {
        uint256 dangerTime = lastCheckIn + checkInInterval;
        return block.timestamp >= dangerTime ? 0 : dangerTime - block.timestamp;
    }
    
    function getTimeUntilTrigger() public view returns (uint256) {
        uint256 triggerTime = lastCheckIn + checkInInterval + gracePeriod;
        return block.timestamp >= triggerTime ? 0 : triggerTime - block.timestamp;
    }

    function triggerSwitch() external notPaused {
        uint256 gasStart = gasleft();
        
        if (isOwnerAlive()) revert OwnerStillAlive();
        
        uint256 balance = address(this).balance;
        if (balance == 0) return;
        
        emit Triggered(msg.sender, block.timestamp, balance);
        
        // Try primary heir first
        (bool success, ) = payable(heir).call{value: balance}("");
        if (!success) {
            // Try backup heirs
            for (uint256 i = 0; i < backupHeirs.length; i++) {
                (bool backupSuccess, ) = payable(backupHeirs[i]).call{value: balance}("");
                if (backupSuccess) {
                    break;
                }
            }
        }
        
        _updateGasUsage("triggerSwitch", gasStart);
    }
 
    function withdraw(uint256 amount) external onlyOwner {
        if (amount > address(this).balance) revert InsufficientBalance();
        
        emit Withdrawn(owner, amount);

        (bool success, ) = payable(owner).call{value: amount}("");
        if (!success) revert TransferFailed();
    }
    
    function batchWithdraw(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner {
        require(recipients.length == amounts.length, "Arrays length mismatch");
        
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        
        if (totalAmount > address(this).balance) revert InsufficientBalance();
        
        for (uint256 i = 0; i < recipients.length; i++) {
            (bool success, ) = payable(recipients[i]).call{value: amounts[i]}("");
            if (!success) revert TransferFailed();
            emit Withdrawn(recipients[i], amounts[i]);
        }
    }

    function pauseSwitch() external onlyOwner {
        isPaused = true;
        emit Paused();
    }
    
    function resumeSwitch() external onlyOwner {
        isPaused = false;
        emit Resumed();
    }
    
    function emergencyChangeOwner(address _newOwner) external {
        if (msg.sender != heir) revert NotOwner();
        if (isOwnerAlive()) revert OwnerStillAlive();
        if (_newOwner == address(0)) revert ZeroAddress();
        
        address previousOwner = owner;
        owner = _newOwner;
        lastCheckIn = block.timestamp;
        checkInStreak = 0; // Reset streak
        
        // Update authorization
        authorizedUsers[previousOwner] = false;
        authorizedUsers[_newOwner] = true;
        
        emit EmergencyOwnershipTransferred(previousOwner, _newOwner);
    }

    function checkInAndSetHeir(address _newHeir) external onlyOwner notPaused {
        if (_newHeir == address(0)) revert ZeroAddress();

        lastCheckIn = block.timestamp;
        checkInStreak++;
        totalCheckIns++;
        
        checkInHistory.push(CheckInEvent({
            timestamp: block.timestamp,
            by: msg.sender,
            streakCount: checkInStreak
        }));
        
        emit CheckedIn(msg.sender, lastCheckIn, checkInStreak);

        if (_newHeir != heir) {
            address previousHeir = heir;
            heir = _newHeir;
            
            authorizedUsers[previousHeir] = false;
            authorizedUsers[_newHeir] = true;
            
            heirChangeHistory.push(HeirChangeEvent({
                timestamp: block.timestamp,
                previousHeir: previousHeir,
                newHeir: _newHeir,
                changedBy: msg.sender
            }));
            
            emit HeirChanged(previousHeir, _newHeir, msg.sender);
        }
    }
    
    function getContractDetails() external view returns (
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
        _owner = owner;
        _heir = heir;
        _lastCheckIn = lastCheckIn;
        _checkInInterval = checkInInterval;
        _gracePeriod = gracePeriod;
        _timeUntilDanger = getTimeUntilDanger();
        _timeUntilTrigger = getTimeUntilTrigger();
        _paused = isPaused;
        _balance = address(this).balance;
        _checkInStreak = checkInStreak;
        _totalCheckIns = totalCheckIns;
    }
    
    function getBackupHeirs() external view returns (address[] memory) {
        return backupHeirs;
    }
    
    function getCheckInHistory(uint256 limit) external view returns (CheckInEvent[] memory) {
        uint256 length = checkInHistory.length;
        if (limit > length) limit = length;
        
        CheckInEvent[] memory recent = new CheckInEvent[](limit);
        for (uint256 i = 0; i < limit; i++) {
            recent[i] = checkInHistory[length - 1 - i];
        }
        return recent;
    }
    
    function getHeirChangeHistory(uint256 limit) external view returns (HeirChangeEvent[] memory) {
        uint256 length = heirChangeHistory.length;
        if (limit > length) limit = length;
        
        HeirChangeEvent[] memory recent = new HeirChangeEvent[](limit);
        for (uint256 i = 0; i < limit; i++) {
            recent[i] = heirChangeHistory[length - 1 - i];
        }
        return recent;
    }
    
    function getHealthScore() external view returns (uint256) {
        if (totalCheckIns == 0) return 0;
        
        uint256 consistencyScore = (checkInStreak * 100) / totalCheckIns;
        uint256 timeScore = isOwnerAlive() ? 100 : 0;
        uint256 balanceScore = address(this).balance > 0 ? 100 : 0;
        
        return (consistencyScore + timeScore + balanceScore) / 3;
    }
    
    function estimateGas(string calldata functionName) external view returns (uint256) {
        uint256 calls = gasCallCount[functionName];
        if (calls == 0) return 0;
        return avgGasUsed[functionName] / calls;
    }
    
    function _updateGasUsage(string memory functionName, uint256 gasStart) internal {
        uint256 gasUsed = gasStart - gasleft();
        avgGasUsed[functionName] += gasUsed;
        gasCallCount[functionName]++;
    }
    
    function canBTriggered() external view returns (bool) {
        return !isPaused && !isOwnerAlive();
    }
    
    receive() external payable {}
}
