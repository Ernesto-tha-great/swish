// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IRecurringPayment
 * @dev Interface for the RecurringPayment contract
 */
interface IRecurringPayment {
    struct RecurringPayment {
        bytes32 id;
        address payer;
        address payee;
        address tokenAddress;
        uint256 amount;
        uint256 frequency;
        uint256 nextPaymentDue;
        bool isActive;
        bytes32 referenceId;
    }

    event RecurringPaymentCreated(
        bytes32 indexed id,
        address indexed payer,
        address indexed payee,
        address tokenAddress,
        uint256 amount,
        uint256 frequency,
        uint256 nextPaymentDue
    );
    
    event RecurringPaymentExecuted(
        bytes32 indexed id,
        address indexed payer,
        address indexed payee,
        uint256 amount,
        uint256 nextPaymentDue
    );
    
    event RecurringPaymentCancelled(bytes32 indexed id);
    event RecurringPaymentUpdated(bytes32 indexed id);

    function createRecurringPayment(
        bytes32 _id,
        address _payee,
        address _tokenAddress,
        uint256 _amount,
        uint256 _frequency,
        uint256 _firstPaymentDue,
        bytes32 _referenceId
    ) external;

    function executeRecurringPayment(bytes32 _id) external;
    function isPaymentDue(bytes32 _id) external view returns (bool isDue);
    function cancelRecurringPayment(bytes32 _id) external;
    
    function updateRecurringPayment(
        bytes32 _id,
        uint256 _amount,
        uint256 _frequency
    ) external;

    function getRecurringPaymentDetails(bytes32 _id) 
        external 
        view 
        returns (RecurringPayment memory);
}