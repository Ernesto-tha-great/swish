// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IPaymentProcessor
 * @dev Interface for the PaymentProcessor contract
 */
interface IPaymentProcessor {
    struct PaymentRecord {
        bytes32 paymentId;
        address payer;
        address payee;
        address tokenAddress;
        uint256 amount;
        uint256 feeAmount;
        uint256 timestamp;
        bytes32 referenceHash;
    }

    event PaymentProcessed(
        bytes32 indexed paymentId,
        address indexed payer,
        address indexed payee,
        address tokenAddress,
        uint256 amount,
        uint256 feeAmount,
        bytes32 referenceHash
    );

    event FeeUpdated(uint256 newFeePercentage);
    event FeeCollectorUpdated(address newFeeCollector);

    function processPayment(
        bytes32 _paymentId,
        address _payee,
        address _tokenAddress,
        uint256 _amount,
        bytes32 _referenceHash,
        bytes memory _signature
    ) external;

    function processBatchPayment(
        bytes32[] calldata _paymentIds,
        address[] calldata _payees,
        address _tokenAddress,
        uint256[] calldata _amounts,
        bytes32[] calldata _referenceHashes
    ) external;

    function verifyPayment(bytes32 _paymentId) 
        external 
        view 
        returns (bool exists, PaymentRecord memory record);

    function updatePlatformFee(uint256 _newFeePercentage) external;
    function updateFeeCollector(address _newFeeCollector) external;
}