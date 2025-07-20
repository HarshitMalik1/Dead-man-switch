Dead Man Switch Smart Contract
This Solidity smart contract implements a "Dead Man Switch" (or "Liveness Switch") on the Ethereum blockchain. It allows a user (the owner) to designate an heir to receive funds if the owner fails to "check in" within a specified interval and grace period. The contract includes enhanced features like backup heirs, detailed event logging, gas usage tracking, and administrative controls.

Features
•	Owner-Controlled Check-Ins: The owner must regularly call the checkIn() function to reset the timer.

•	Primary Heir Designation: A main heir address is set during deployment and can be changed by the owner.

•	Configurable Intervals:

o	checkInInterval: The period (e.g., 30 days) within which the owner must check in.

o	gracePeriod: An additional buffer period (e.g., 72 hours) after the checkInInterval expires, before the switch can be triggered.

•	Trigger Mechanism: If the owner fails to check in within the checkInInterval plus gracePeriod, any authorised user can call triggerSwitch() to release the contract's Ether balance to the designated heir(s).

•	Enhanced Heir Management:

o	Support for multiple backup heirs in case the primary heir cannot receive funds.

o	Functions to addBackupHeir and removeBackupHeir.

•	Pause/Resume Functionality: The owner can pauseSwitch() and resumeSwitch() to temporarily disable check-ins and triggers.


•	Emergency Ownership Transfer: The primary heir can take over ownership if the original owner is considered "dead" (missed check-ins).

•	Detailed History Tracking:

o	checkInHistory: Logs all owner check-ins.

o	heirChangeHistory: Logs all primary heir changes.

•	Gas Usage Estimation: Tracks and provides average gas usage for specific functions.

•	Health Score: A calculated metric indicating the contract's "liveness" and readiness.

•	Error Handling: Custom errors for clearer revert messages (e.g., NotOwner, OwnerStillAlive, InsufficientBalance).

•	receive() function: Allows the contract to receive plain Ether transfers.



How It Works

1.	Deployment: The owner deploys the contract, specifying the initial heir, checkInInterval (in days), and gracePeriod (in hours). The contract will hold any Ether sent during deployment.

2.	Owner Check-In: The owner periodically calls checkIn(). Each call updates lastCheckIn to the current timestamp and increments the checkInStreak.

3.	Liveness Check: The isOwnerAlive() function determines if the owner has checked in recently enough. It returns true if block.timestamp is less than or equal to lastCheckIn + checkInInterval + gracePeriod.

4.	Trigger Condition: If isOwnerAlive() returns false, meaning the owner has missed their window, triggerSwitch() can be called.

5.	Fund Transfer: When triggerSwitch() is called and the owner is "not alive", the contract attempts to send its entire Ether balance to the primary heir. If that fails, it iterates through backupHeirs until a successful transfer occurs.

6.	Withdrawals: The owner can withdraw() specific amounts or use batchWithdraw() to distribute funds.



Contract Details

•	License: MIT

•	Solidity Version: ^0.8.20



Contract Functions (Key Interactions)

Owner Functions:

•	checkIn(): Resets the timer.

•	setHeir(address _newHeir): Changes the primary heir.

•	addBackupHeir(address _backupHeir): Adds an additional heir.

•	removeBackupHeir(address _backupHeir): Removes a backup heir.

•	setCheckInInterval(uint256 _intervalInDays): Adjusts the check-in frequency.

•	setGracePeriod(uint256 _gracePeriodInHours): Adjusts the grace period.

•	withdraw(uint256 amount): Withdraws Ether from the contract.

•	batchWithdraw(address[] calldata recipients, uint256[] calldata amounts): Distributes Ether to multiple addresses.

•	pauseSwitch(): Temporarily stops check-ins and triggers.

•	resumeSwitch(): Restarts check-ins and triggers.

•	checkInAndSetHeir(address _newHeir): Combines a check-in with an heir update.


Heir/Anyone (Conditional) Functions:
•	triggerSwitch(): Initiates fund transfer if the owner is not alive and the grace period has passed.
•	emergencyChangeOwner(address _newOwner): Allows the primary heir to take ownership if the owner is not alive.

Public View Functions (Read-Only):
•	owner(): Returns the contract owner's address.
•	heir(): Returns the primary heir's address.
•	lastCheckIn(): Returns the timestamp of the last check-in.
•	checkInInterval(): Returns the check-in interval in seconds.
•	gracePeriod(): Returns the grace period in seconds.
•	isOwnerAlive(): Checks if the owner is currently considered alive.
•	getTimeUntilDanger(): Time remaining until checkInInterval expires.
•	getTimeUntilTrigger(): Time remaining until checkInInterval + gracePeriod expires.
•	isPaused(): Checks if the switch is paused.
•	getContractDetails(): Returns a comprehensive set of contract state variables.
•	getBackupHeirs(): Returns the list of backup heirs.
•	getCheckInHistory(uint256 limit): Returns recent check-in events.
•	getHeirChangeHistory(uint256 limit): Returns recent heir change events.
•	getHealthScore(): Returns the calculated health score.
•	estimateGas(string calldata functionName): Provides average gas usage for a function.
•	canBTriggered(): Checks if the switch is ready to be triggered.
