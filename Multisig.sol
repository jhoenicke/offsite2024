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
    }

    function addValidator(
        address validator,
        uint256 newQuorum,
        uint256 _step
    ) public onlyContract {
        require (validator != address(this));
        require (!isValidator[validator]);
        validators.push(validator);
        validatorsReverseMap[validator] = validators.length - 1;
        isValidator[validator] = true;

        quorum = newQuorum;
        step = _step;
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

        quorum = newQuorum;
        step = _step;
    }


    function replaceValidator(
        address validator,
        address newValidator
    )
        public onlyContract
    {
        require (isValidator[validator]);
        require (!isValidator[newValidator]);
        isValidator[validator] = false;
        isValidator[newValidator] = true;

        uint256 validatorIndex = validatorsReverseMap[validator];
        validators[validatorIndex] = newValidator;
        validatorsReverseMap[newValidator] = validatorIndex;
        delete validatorsReverseMap[validator];
    }

       function fib(uint256 n) external pure returns(uint256 a) { 
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
    }

    function changeQuorum(uint256 _quorum, uint256 _step) public onlyContract
    { 
        //uint256 expected_qourum 
        require(_quorum <= validators.length &&
                _quorum != 0 &&
                _quorum == this.fib(_step + 1));  

        quorum = _quorum;
        step = step;
    }

    function transactionExists(bytes32 transactionId)
        public
        view
        returns (bool)
    {
        // check that reverse map points to the right id.  Avoid reverts if list is empty.
        return transactionIds.length > 0 &&
            transactionIds[transactionIdsReverseMap[transactionId]] == transactionId;
    }

    function addTransaction(
        bytes32 transactionId,
        address destination,
        uint256 value,
        bytes calldata data,
        bool hasReward
    ) onlyValidator internal {
        transactionIds.push(transactionId);
        transactionIdsReverseMap[transactionId] = transactionIds.length - 1;

        transactions[transactionId].destination = destination;
        transactions[transactionId].value = value;
        transactions[transactionId].data = data;
        transactions[transactionId].hasReward = hasReward;
    }

    function voteForTransaction(
        bytes32 transactionId,
        address destination,
        uint256 value,
        bytes calldata data,
        bool hasReward
    ) onlyValidator public payable {
        if (!transactionExists(transactionId)) {
            addTransaction(transactionId, destination, value, data, hasReward);
        } else {
            require(transactions[transactionId].destination == destination);
            require(transactions[transactionId].value == value);
            require(keccak256(transactions[transactionId].data) == keccak256(data));
            require(transactions[transactionId].hasReward == hasReward);
        }

        confirmations[transactionId][msg.sender] = true;
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
        require (transactionId != 0);
        uint256 transactionIndex = transactionIdsReverseMap[transactionId];

        require (transactionIds[transactionIndex] == transactionId);

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
    }
}
