// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract DeadManSwitch {
    
    address public owner;          
    address public heir;          
    uint256 public lastCheckIn;       
    uint256 public checkInInterval;   
    bool public isPaused;

    error NotOwner();
    error ZeroAddress();
    error SwitchPaused();
    error OwnerStillAlive();
    error InsufficientBalance();
    error TransferFailed();
    error InvalidInterval();
    
    event CheckedIn(address indexed owner, uint256 timestamp);
    event HeirChanged(address indexed previousHeir, address indexed newHeir);
    event Triggered(address indexed by, uint256 timestamp);
    event Withdrawn(address indexed to, uint256 amount);
    event Paused();
    event Resumed();
    event IntervalChanged(uint256 newInterval);

    constructor(address _heir, uint256 _intervalInDays) payable {
        if (_heir == address(0)) revert ZeroAddress();
        if (_intervalInDays == 0) revert InvalidInterval();
        
        owner = msg.sender;
        heir = _heir;
        checkInInterval = _intervalInDays * 1 days;
        lastCheckIn = block.timestamp;
  
    }
    
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }
    
    modifier notPaused() {
        if (isPaused) revert SwitchPaused();
        _;
    }

    function checkIn() external onlyOwner notPaused {
        lastCheckIn = block.timestamp;
        emit CheckedIn(msg.sender, lastCheckIn);
    }
    
    function setHeir(address _newHeir) external onlyOwner {
        if (_newHeir == address(0)) revert ZeroAddress();
        
        address previousHeir = heir;
        heir = _newHeir;
        emit HeirChanged(previousHeir, _newHeir);
    }
    
    function setCheckInInterval(uint256 _intervalInDays) external onlyOwner {
        if (_intervalInDays == 0) revert InvalidInterval();
        
        checkInInterval = _intervalInDays * 1 days;
        emit IntervalChanged(checkInInterval);
    }

    function isOwnerAlive() public view returns (bool) {
        return block.timestamp <= lastCheckIn + checkInInterval;
    }

    function triggerSwitch() external notPaused {
        if (isOwnerAlive()) revert OwnerStillAlive();
        
        uint256 balance = address(this).balance;
        if (balance == 0) return; // Nothing to transfer
        
        emit Triggered(msg.sender, block.timestamp);

        (bool success, ) = payable(heir).call{value: balance}("");
        if (!success) revert TransferFailed();
    }
 
    function withdraw(uint256 amount) external onlyOwner {
        if (amount > address(this).balance) revert InsufficientBalance();
        
        emit Withdrawn(owner, amount);

        (bool success, ) = payable(owner).call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    function pauseSwitch() external onlyOwner {
        isPaused = true;
        emit Paused();
    }
    
    function resumeSwitch() external onlyOwner {
        isPaused = false;
        emit Resumed();
    }

    function getContractDetails() external view returns (
        address _owner,
        address _heir,
        uint256 _lastCheckIn,
        uint256 _checkInInterval,
        uint256 _timeLeft,
        bool _paused,
        uint256 _balance
    ) {
        _owner = owner;
        _heir = heir;
        _lastCheckIn = lastCheckIn;
        _checkInInterval = checkInInterval;
        _paused = isPaused;
        _balance = address(this).balance;

        unchecked {
            uint256 deadline = lastCheckIn + checkInInterval;
            _timeLeft = block.timestamp >= deadline ? 0 : deadline - block.timestamp;
        }
    }

    function getTimeUntilTrigger() external view returns (uint256) {
        uint256 deadline = lastCheckIn + checkInInterval;
        return block.timestamp >= deadline ? 0 : deadline - block.timestamp;
    }
    
    function canBTriggered() external view returns (bool) {
        return !isPaused && !isOwnerAlive();
    }

    function emergencyChangeOwner(address _newOwner) external {
        if (msg.sender != heir) revert NotOwner();
        if (isOwnerAlive()) revert OwnerStillAlive();
        if (_newOwner == address(0)) revert ZeroAddress();
        
        owner = _newOwner;
        lastCheckIn = block.timestamp; // Reset timer
    }

    function checkInAndSetHeir(address _newHeir) external onlyOwner notPaused {
        if (_newHeir == address(0)) revert ZeroAddress();

        lastCheckIn = block.timestamp;
        emit CheckedIn(msg.sender, lastCheckIn);

        if (_newHeir != heir) {
            address previousHeir = heir;
            heir = _newHeir;
            emit HeirChanged(previousHeir, _newHeir);
        }
    }
    
    receive() external payable {}

}
