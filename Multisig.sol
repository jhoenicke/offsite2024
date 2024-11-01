pragma solidity ^0.8.7;

import "./State.sol";

contract Multisig is State {
    mapping(bytes32 => uint256) confirmationCount;

    function isVoteToChangeValidator(bytes calldata data, address destination)
        public
        view
        returns (bool)
    {
        if (data.length > 4) {
            return
                (bytes4(data[:4]) == this.addValidator.selector || bytes4(data[:4]) == this.replaceValidator.selector || bytes4(data[:4]) == this.removeValidator.selector) &&
                destination == address(this);
        }

        return false;
    }


    modifier onlyValidator(){
        require(isValidator[msg.sender]);
        _;
    }

    modifier onlyContract(){
        require(msg.sender == address(this));
        _;
    }

    modifier reentracy(){
        require(guard == 1);
        guard = 2;
        _;
        guard = 1;
    }

    modifier reentracyChack(){
        require(guard == 1);
        _;
    }

    constructor(address[] memory newValidators,  uint256 _quorum, uint256 _step)
    {
        validators = newValidators;
        require(newValidators[0] == address(0));
        setQuorum(_quorum, _step);
        transactionIds.push(0);

        for (uint256 i = 1; i < newValidators.length; i++) {
            address validator = newValidators[i];
            isValidator[validator] = true;
            validatorsReverseMap[validator] = i;
        }
    }

    function setQuorum(uint256 newQuorum, uint256 newStep) internal {
        require(newQuorum <= validators.length &&
            newQuorum != 0 &&
            newQuorum == this.fib(newStep + 1));

        quorum = newQuorum;
        step = newStep;
    }

    function addValidator(
        address validator,
        uint256 newQuorum,
        uint256 _step
    ) public onlyContract {
        require (validator != address(0));
        require (validator != address(this));
        require (!isValidator[validator]);
        validators.push(validator);
        validatorsReverseMap[validator] = validators.length - 1;
        isValidator[validator] = true;

        setQuorum(newQuorum,_step);
    }

    function removeValidator(
        address validator,
        uint256 newQuorum,
        uint256 _step
    ) public onlyContract {
        require (isValidator[validator]);
        isValidator[validator] = false;
        uint256 validatorIndex = validatorsReverseMap[validator];

        // move the last validator to take it's place.
        address lastValidator = validators[validators.length - 1];
        validators[validatorIndex] = lastValidator;
        validatorsReverseMap[lastValidator] = validatorIndex;

        // remove the validator
        validators.pop();
        delete validatorsReverseMap[validator];

        bytes32 transactionId;
        for (uint i = 0; i < transactionIds.length; i++) {
            transactionId = transactionIds[i];
            if(confirmations[transactionId][validator]){
                confirmationCount[transactionId] -= 1;
                confirmations[transactionId][validator] = false;
            }
        }

        setQuorum(newQuorum,_step);
    }


    function replaceValidator(
        address validator,
        address newValidator
    )
        public onlyContract
    {
        require (isValidator[validator]);
        require (!isValidator[newValidator]);
        require (newValidator != address(0));
        require (newValidator != address(this));
        isValidator[validator] = false;
        isValidator[newValidator] = true;

        uint256 validatorIndex = validatorsReverseMap[validator];
        validators[validatorIndex] = newValidator;
        validatorsReverseMap[newValidator] = validatorIndex;
        delete validatorsReverseMap[validator];

        bytes32 transactionId;
        for (uint i = 0; i < transactionIds.length; i++) {
            transactionId = transactionIds[i];
            if(confirmations[transactionId][validator]){
                confirmations[transactionId][validator] = false;
                confirmations[transactionId][newValidator] = true;
            }
        }
    }

    function fib(uint256 n) external pure returns(uint256 a) {
        a = 0;
        uint256 fibnext = 1;
        while (n > 0) {
            uint256 old = a;
            a = fibnext;
            fibnext = fibnext + old;
            n--;
        }
        /*
        if (n == 0) {
            return 0;
        }
        uint256 h = n / 2;
        uint256 mask = 1;
        // find highest set bit in n
        while(mask <= h) {
            mask <<= 1;
        }
        mask >>= 1;
        a = 1;
        uint256 b = 1;
        uint256 c;
        while(mask > 0) {
            c = a * a+b * b;
            if (n & mask > 0) {
                b = b * (b + 2 * a);
                a = c;
            } else {
                a = a * (2 * b - a);
                b = c;
            }
            mask >>= 1;
        }
        return a;
        */
    }

    function changeQuorum(uint256 _quorum, uint256 _step) public onlyContract
    {
        setQuorum(_quorum,_step);
    }

    function transactionExists(bytes32 transactionId)
        public
        view
        returns (bool)
    {
        // check that reverse map points to the right id.  Avoid reverts if list is empty.
        return transactionIds[transactionIdsReverseMap[transactionId]] != 0;
    }

    function addTransaction(
        bytes32 transactionId,
        address destination,
        uint256 value,
        bytes calldata data,
        bool hasReward
    ) onlyValidator internal {
        require(destination != address(0));
        transactionIds.push(transactionId);
        transactionIdsReverseMap[transactionId] = transactionIds.length - 1;

        transactions[transactionId].destination = destination;
        transactions[transactionId].value = value;
        transactions[transactionId].data = data;
        transactions[transactionId].hasReward = hasReward;
        if(isVoteToChangeValidator(data, destination)){
            transactions[transactionId].validatorVotePeriod = block.timestamp + ADD_VALIDATOR_VOTE_PERIOD;
        }
        else{
            transactions[transactionId].validatorVotePeriod = 0;
        }
    }

    function voteForTransaction(
        bytes32 transactionId,
        address destination,
        uint256 value,
        bytes calldata data,
        bool hasReward
    ) onlyValidator public payable {
        require(transactionId != 0);
        if (!transactionExists(transactionId)) {
            require(msg.value == value);
            require(destination!= address(0));

            sideRewardsPot += value;
            addTransaction(transactionId, destination, value, data, hasReward);
        } else {
            require(msg.value == 0);
            require(transactions[transactionId].destination == destination);
            require(transactions[transactionId].value == value);
            require(keccak256(transactions[transactionId].data) == keccak256(data));
            require(transactions[transactionId].hasReward == hasReward);
        }

        if(transactions[transactionId].validatorVotePeriod != 0){
            require(block.timestamp <= transactions[transactionId].validatorVotePeriod);
        }

        if(!confirmations[transactionId][msg.sender]){
            confirmationCount[transactionId] += 1;
            confirmations[transactionId][msg.sender] = true;
        }

        if (isConfirmed(transactionId) && !transactions[transactionId].executed
            && transactions[transactionId].validatorVotePeriod != 0) {
            executeTransaction(transactionId);
        }
    }

    function executeTransaction(bytes32 transactionId) public
    {
        require(transactionExists(transactionId));
        require(!transactions[transactionId].executed);
        require(isConfirmed(transactionId));

        require(transactions[transactionId].value >= WRAPPING_FEE);

        //transactions[transactionId].executed = true;

        //require(_getApprovalCount(transactionId) >= required, "approvals < required");
        Transaction storage transaction = transactions[transactionId];
        transaction.executed = true;

        //currentContract.transactions[transactionId].value >= WRAPPING_FEE() &&
        //        rewardsPotBefore + WRAPPING_FEE() <= rewardsPot()

        uint256 sendValue = transaction.value;
        if(transaction.hasReward){
            sendValue -= WRAPPING_FEE;
            rewardsPot += WRAPPING_FEE;
        }
        sideRewardsPot -= transactions[transactionId].value;

        (bool success, ) = transaction.destination.call{value: sendValue}(
        transaction.data
        );

        //require(success, "Transaction failed");
        //if(transaction.hasReward){
        //}

        //send to the user transactions[transactionId].value - WRAPPING_FEE
    }

    function removeTransaction(bytes32 transactionId) public onlyContract {
        uint256 transactionIndex = transactionIdsReverseMap[transactionId];
        require (transactionIndex != 0);

        for (uint256 i = 1; i < validators.length; i++) {
            confirmations[transactionId][validators[i]] = false;
        }
        confirmationCount[transactionId] = 0;

        if (!transactions[transactionId].executed) {
            sideRewardsPot -= transactions[transactionId].value;
            rewardsPot += transactions[transactionId].value;
        }

        // move the last validator to take it's place.
        bytes32 lastTransactionId = transactionIds[transactionIds.length - 1];
        transactionIds[transactionIndex] = lastTransactionId;
        transactionIdsReverseMap[lastTransactionId] = transactionIndex;

        // remove the validator
        transactionIds.pop();
        delete transactionIdsReverseMap[transactionId];
        delete transactions[transactionId];
    }

    function isConfirmed(bytes32 transactionId) public view returns (bool) {
        return getConfirmationCount(transactionId) >= quorum;
    }

    function getDataOfTransaction(bytes32 id) external view returns (bytes memory data){
        data = transactions[id].data;
    }

    function hash(bytes memory data) external pure returns (bytes32 result)
    {
        result = keccak256(data);
    }

    function getConfirmationCount(bytes32 transactionId)
        public
        view
        returns (uint256 count)
    {
        return confirmationCount[transactionId];
    }

    function distributeRewards() public reentracy
    {
        address payable validator;
        require(validators.length > 1);
        uint256 rewards = rewardsPot / (validators.length - 1);
        for (uint i = 1; i < validators.length; i++) {
            validator = payable(validators[i]);
            validator.transfer(rewards);
            rewardsPot -= rewards;
        }

        lastWithdrawalTime = block.timestamp;
    }
}
