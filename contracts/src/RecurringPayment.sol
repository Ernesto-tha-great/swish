// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IRecurringPayment.sol";
import "./interfaces/IPaymentProcessor.sol";

/**
 * @title RecurringPayment
 * @dev Manages recurring payment subscriptions and triggers
 */
contract RecurringPayment is IRecurringPayment, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAYMENT_MANAGER_ROLE = keccak256("PAYMENT_MANAGER_ROLE");

    // PaymentProcessor reference for executing payments
    IPaymentProcessor public paymentProcessor;

    // Maps ID to RecurringPayment
    mapping(bytes32 => RecurringPayment) public recurringPayments;
    // Maps user address to array of their recurring payment IDs
    mapping(address => bytes32[]) public userRecurringPayments;
    // Maps user address to array of payments they receive
    mapping(address => bytes32[]) public userReceivedPayments;

    /**
     * @dev Constructor
     * @param _paymentProcessor Address of the PaymentProcessor contract
     */
    constructor(address _paymentProcessor) {
        require(_paymentProcessor != address(0), "Invalid payment processor");
        
        paymentProcessor = IPaymentProcessor(_paymentProcessor);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PAYMENT_MANAGER_ROLE, msg.sender);
    }

    /**
     * @dev Create a new recurring payment
     * @param _id Unique ID
     * @param _payee Recipient
     * @param _tokenAddress Payment token
     * @param _amount Payment amount
     * @param _frequency Payment frequency in seconds
     * @param _firstPaymentDue Timestamp of first payment
     * @param _referenceId Backend reference ID
     */
    function createRecurringPayment(
        bytes32 _id,
        address _payee,
        address _tokenAddress,
        uint256 _amount,
        uint256 _frequency,
        uint256 _firstPaymentDue,
        bytes32 _referenceId
    ) external override {
        require(_payee != address(0), "Invalid payee");
        require(_tokenAddress != address(0), "Invalid token");
        require(_amount > 0, "Amount must be greater than 0");
        require(_frequency > 0, "Frequency must be greater than 0");
        require(_firstPaymentDue > block.timestamp, "First payment must be in future");
        require(recurringPayments[_id].id == bytes32(0), "ID already exists");
        
        RecurringPayment storage newPayment = recurringPayments[_id];
        newPayment.id = _id;
        newPayment.payer = msg.sender;
        newPayment.payee = _payee;
        newPayment.tokenAddress = _tokenAddress;
        newPayment.amount = _amount;
        newPayment.frequency = _frequency;
        newPayment.nextPaymentDue = _firstPaymentDue;
        newPayment.isActive = true;
        newPayment.referenceId = _referenceId;
        
        userRecurringPayments[msg.sender].push(_id);
        userReceivedPayments[_payee].push(_id);
        
        emit RecurringPaymentCreated(
            _id,
            msg.sender,
            _payee,
            _tokenAddress,
            _amount,
            _frequency,
            _firstPaymentDue
        );
    }

    /**
     * @dev Execute a recurring payment
     * @param _id ID of the recurring payment to execute
     */
    function executeRecurringPayment(bytes32 _id) external nonReentrant override {
        RecurringPayment storage payment = recurringPayments[_id];
        
        require(payment.id != bytes32(0), "Payment does not exist");
        require(payment.isActive, "Payment is not active");
        require(block.timestamp >= payment.nextPaymentDue, "Payment not due yet");
        
        // Update next payment due date
        uint256 previousDueDate = payment.nextPaymentDue;
        payment.nextPaymentDue = previousDueDate + payment.frequency;
        
        // Generate a unique payment ID for the transaction
        bytes32 paymentId = keccak256(abi.encodePacked(
            payment.id,
            payment.payer,
            payment.payee,
            previousDueDate,
            block.timestamp
        ));
        
        // Create a reference hash linking to the recurring payment
        bytes32 referenceHash = keccak256(abi.encodePacked(
            "RECURRING",
            payment.id,
            previousDueDate
        ));
        
        // Transfer tokens
        IERC20 token = IERC20(payment.tokenAddress);
        
        // Approve payment processor to spend tokens
        token.approve(address(paymentProcessor), payment.amount);
        
        // Process payment through payment processor
        paymentProcessor.processPayment(
            paymentId,
            payment.payee,
            payment.tokenAddress,
            payment.amount,
            referenceHash,
            new bytes(0) // Empty signature since we're calling directly
        );
        
        emit RecurringPaymentExecuted(
            _id,
            payment.payer,
            payment.payee,
            payment.amount,
            payment.nextPaymentDue
        );
    }

    /**
     * @dev Check if a recurring payment is due
     * @param _id ID of the recurring payment
     * @return isDue Whether the payment is due
     */
    function isPaymentDue(bytes32 _id) external view override returns (bool isDue) {
        RecurringPayment storage payment = recurringPayments[_id];
        
        if (payment.id == bytes32(0) || !payment.isActive) {
            return false;
        }
        
        return block.timestamp >= payment.nextPaymentDue;
    }

    /**
     * @dev Cancel a recurring payment
     * @param _id ID of the recurring payment to cancel
     */
    function cancelRecurringPayment(bytes32 _id) external override {
        RecurringPayment storage payment = recurringPayments[_id];
        
        require(payment.id != bytes32(0), "Payment does not exist");
        require(
            payment.payer == msg.sender || hasRole(PAYMENT_MANAGER_ROLE, msg.sender),
            "Not authorized"
        );
        
        payment.isActive = false;
        
        emit RecurringPaymentCancelled(_id);
    }

    /**
     * @dev Update a recurring payment
     * @param _id ID of the payment to update
     * @param _amount New payment amount
     * @param _frequency New payment frequency
     */
    function updateRecurringPayment(
        bytes32 _id,
        uint256 _amount,
        uint256 _frequency
    ) external override {
        RecurringPayment storage payment = recurringPayments[_id];
        
        require(payment.id != bytes32(0), "Payment does not exist");
        require(payment.isActive, "Payment is not active");
        require(
            payment.payer == msg.sender || hasRole(PAYMENT_MANAGER_ROLE, msg.sender),
            "Not authorized"
        );
        require(_amount > 0, "Amount must be greater than 0");
        require(_frequency > 0, "Frequency must be greater than 0");
        
        payment.amount = _amount;
        payment.frequency = _frequency;
        
        emit RecurringPaymentUpdated(_id);
    }

    /**
     * @dev Get details of a recurring payment
     * @param _id ID of the recurring payment
     * @return Payment details
     */
    function getRecurringPaymentDetails(bytes32 _id) 
        external 
        view 
        override
        returns (RecurringPayment memory) 
    {
        require(recurringPayments[_id].id != bytes32(0), "Payment does not exist");
        return recurringPayments[_id];
    }

    /**
     * @dev Get all recurring payments for a user (as payer)
     * @param _user Address of the user
     * @return Array of recurring payment IDs
     */
    function getUserRecurringPayments(address _user) 
        external 
        view 
        returns (bytes32[] memory) 
    {
        return userRecurringPayments[_user];
    }

    /**
     * @dev Get all recurring payments received by a user
     * @param _user Address of the user
     * @return Array of recurring payment IDs
     */
    function getUserReceivedPayments(address _user) 
        external 
        view 
        returns (bytes32[] memory) 
    {
        return userReceivedPayments[_user];
    }

    /**
     * @dev Set the payment processor address
     * @param _paymentProcessor New payment processor address
     */
    function setPaymentProcessor(address _paymentProcessor) external onlyRole(ADMIN_ROLE) {
        require(_paymentProcessor != address(0), "Invalid payment processor");
        paymentProcessor = IPaymentProcessor(_paymentProcessor);
    }
}