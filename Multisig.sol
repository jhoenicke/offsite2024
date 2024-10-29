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

    function changeQuorum(uint256 _quorum, uint256 _step)
        public onlyContract
    {
        quorum = _quorum;
        step = _step;
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

    function voteForTransaction(
        bytes32 transactionId,
        address destination,
        uint256 value,
        bytes calldata data,
        bool hasReward
    ) onlyValidator public payable {
        if (!transactionExists(transactionId)) {
            // TODO
            // addTransaction(transactionId, );
        }
    }

    function executeTransaction(bytes32 transactionId) public
    {
    }

    function removeTransaction(bytes32 transactionId) public {
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
