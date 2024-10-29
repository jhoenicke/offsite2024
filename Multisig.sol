pragma solidity ^0.8.7;

import "./State.sol";

contract Multisig is State {

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

    modifier onlySelfCall() {
        require(msg.sender == address(this));
        _;
    }

    constructor(address[] memory newValidators,  uint256 _quorum, uint256 _step)
    {
        require(newValidators.length >= _quorum, "Not enough validators for quorum");
        validators = newValidators;
        quorum = _quorum;
        step = _step;
        
        for (uint256 i = 0; i < newValidators.length; i++) {
            address validator = newValidators[i];
            isValidator[validator] = true;
            validatorsReverseMap[validator] = i;
        }
    }

    function addValidator(
        address validator,
        uint256 newQuorum,
        uint256 _step
    ) public onlySelfCall {
        require(!isValidator[validator], "Already a validator");
        validators.push(validator);
        isValidator[validator] = true;
        validatorsReverseMap[validator] = validators.length - 1;
        quorum = newQuorum;
        step = _step;
    }


    function removeValidator(
        address validator,
        uint256 newQuorum,
        uint256 _step
    ) public {
        require(isValidator[validator], "Not a validator");
        uint256 index = validatorsReverseMap[validator];
        
        validators[index] = validators[validators.length - 1];
        validators.pop();
        
        delete isValidator[validator];
        delete validatorsReverseMap[validator];

        deleteAllConfirmations(validator);
        
        quorum = newQuorum;
        step = _step;
    }


    function replaceValidator(
        address validator,
        address newValidator
    )
        public
    {}

    function changeQuorum(uint256 _quorum, uint256 _step)
        public onlySelfCall()
    {
    }

    function transactionExists(bytes32 transactionId)
        public
        view
        returns (bool)
    {
    }

    function voteForTransaction(
        bytes32 transactionId,
        address destination,
        uint256 value,
        bytes calldata data,
        bool hasReward
    ) public payable {
    }

    function executeTransaction(bytes32 transactionId) public
    {
    }

    function removeTransaction(bytes32 transactionId) public {
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
        for (uint256 i = 0; i < validators.length; i++) {
            if (confirmations[transactionId][validators[i]]) {
                count += 1;
            }
        }
    }

    function distributeRewards() public reentracy
    {
    }

    function deleteAllConfirmations(address validator) internal {
        require(isValidator[validator], "Not a validator");

        for (uint256 i = 0; i < transactionIds.length; i++) {
            bytes32 transactionId = transactionIds[i];
            
            if (confirmations[transactionId][validator]) {
                confirmations[transactionId][validator] = false;
            }
        }
    }
}