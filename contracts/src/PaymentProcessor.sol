// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interfaces/IPaymentProcessor.sol";
import "./interfaces/ITokenRegistry.sol";

/**
 * @title PaymentProcessor
 * @dev Handles cryptocurrency payments for invoices and payrolls
 */
contract PaymentProcessor is IPaymentProcessor, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAYMENT_MANAGER_ROLE = keccak256("PAYMENT_MANAGER_ROLE");

    // State variables
    address public feeCollector;
    uint256 public platformFeePercentage; // In basis points (1/100 of a percent)
    uint256 public constant MAX_FEE = 500; // 5% max fee
    ITokenRegistry public tokenRegistry;
    
    // Maps paymentId to PaymentRecord
    mapping(bytes32 => PaymentRecord) private payments;
    // Maps a hash of (invoice ID + amount + token) to bool to prevent double payment
    mapping(bytes32 => bool) private processedPayments;

    /**
     * @dev Constructor
     * @param _feeCollector Address that will receive platform fees
     * @param _feePercentage Platform fee in basis points (1/100 of a percent)
     * @param _tokenRegistry Address of the TokenRegistry contract
     */
    constructor(
        address _feeCollector, 
        uint256 _feePercentage,
        address _tokenRegistry
    ) {
        require(_feeCollector != address(0), "Invalid fee collector");
        require(_feePercentage <= MAX_FEE, "Fee too high");
        require(_tokenRegistry != address(0), "Invalid token registry");
        
        feeCollector = _feeCollector;
        platformFeePercentage = _feePercentage;
        tokenRegistry = ITokenRegistry(_tokenRegistry);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PAYMENT_MANAGER_ROLE, msg.sender);
    }

    /**
     * @dev Process a payment for an invoice
     * @param _paymentId Unique identifier from backend
     * @param _payee Recipient of the payment
     * @param _tokenAddress Address of the token to use for payment
     * @param _amount Amount to pay
     * @param _referenceHash Hash of the invoice details (stored off-chain)
     * @param _signature Signature authorizing this payment (optional)
     */
    function processPayment(
        bytes32 _paymentId,
        address _payee,
        address _tokenAddress,
        uint256 _amount,
        bytes32 _referenceHash,
        bytes memory _signature
    ) external nonReentrant override {
        require(_payee != address(0), "Invalid payee");
        require(_tokenAddress != address(0), "Invalid token");
        require(_amount > 0, "Amount must be greater than 0");
        require(payments[_paymentId].paymentId == bytes32(0), "Payment ID already used");
        
        // Create a hash to prevent double-processing the same payment
        bytes32 paymentHash = keccak256(abi.encodePacked(_paymentId, _payee, _tokenAddress, _amount));
        require(!processedPayments[paymentHash], "Payment already processed");
        
        // Verify signature if it's not from an authorized payment manager
        if (!hasRole(PAYMENT_MANAGER_ROLE, msg.sender)) {
            bytes32 messageHash = keccak256(abi.encodePacked(
                _paymentId, 
                _payee, 
                _tokenAddress, 
                _amount, 
                _referenceHash
            ));
            // Prefix the hash according to EIP-191
            bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
            address signer = ECDSA.recover(ethSignedMessageHash, _signature);
            require(hasRole(PAYMENT_MANAGER_ROLE, signer), "Invalid signature");
        }
        
        // Calculate fee
        uint256 feeAmount = (_amount * platformFeePercentage) / 10000;
        uint256 payeeAmount = _amount - feeAmount;
        
        // Mark as processed
        processedPayments[paymentHash] = true;
        
        // Store minimal payment information on-chain
        payments[_paymentId] = PaymentRecord({
            paymentId: _paymentId,
            payer: msg.sender,
            payee: _payee,
            tokenAddress: _tokenAddress,
            amount: _amount,
            feeAmount: feeAmount,
            timestamp: block.timestamp,
            referenceHash: _referenceHash
        });
        
        // Transfer tokens
        IERC20 token = IERC20(_tokenAddress);
        
        // Transfer payment to payee
        token.safeTransferFrom(msg.sender, _payee, payeeAmount);
        
        // Transfer fee to fee collector if fee exists
        if (feeAmount > 0) {
            token.safeTransferFrom(msg.sender, feeCollector, feeAmount);
        }
        
        emit PaymentProcessed(
            _paymentId,
            msg.sender,
            _payee,
            _tokenAddress,
            _amount,
            feeAmount,
            _referenceHash
        );
    }

    /**
     * @dev Process a batch payment (for payroll or multiple invoices)
     * @param _paymentIds Array of unique identifiers
     * @param _payees Array of payment recipients
     * @param _tokenAddress Address of the token to use for all payments
     * @param _amounts Array of payment amounts
     * @param _referenceHashes Array of reference hashes
     */
    function processBatchPayment(
        bytes32[] calldata _paymentIds,
        address[] calldata _payees,
        address _tokenAddress,
        uint256[] calldata _amounts,
        bytes32[] calldata _referenceHashes
    ) external nonReentrant onlyRole(PAYMENT_MANAGER_ROLE) override {
        require(_paymentIds.length == _payees.length, "Array length mismatch");
        require(_payees.length == _amounts.length, "Array length mismatch");
        require(_amounts.length == _referenceHashes.length, "Array length mismatch");
        require(_tokenAddress != address(0), "Invalid token");
        
        uint256 totalAmount = 0;
        uint256 totalFees = 0;
        
        // Calculate total amount and validate data
        for (uint256 i = 0; i < _amounts.length; i++) {
            require(_payees[i] != address(0), "Invalid payee");
            require(_amounts[i] > 0, "Amount must be greater than 0");
            require(payments[_paymentIds[i]].paymentId == bytes32(0), "Payment ID already used");
            
            bytes32 paymentHash = keccak256(abi.encodePacked(_paymentIds[i], _payees[i], _tokenAddress, _amounts[i]));
            require(!processedPayments[paymentHash], "Payment already processed");
            processedPayments[paymentHash] = true;
            
            uint256 feeAmount = (_amounts[i] * platformFeePercentage) / 10000;
            
            // Store payment record
            payments[_paymentIds[i]] = PaymentRecord({
                paymentId: _paymentIds[i],
                payer: msg.sender,
                payee: _payees[i],
                tokenAddress: _tokenAddress,
                amount: _amounts[i],
                feeAmount: feeAmount,
                timestamp: block.timestamp,
                referenceHash: _referenceHashes[i]
            });
            
            totalAmount += _amounts[i];
            totalFees += feeAmount;
        }
        
        // Transfer total amount from sender to this contract first
        IERC20 token = IERC20(_tokenAddress);
        token.safeTransferFrom(msg.sender, address(this), totalAmount);
        
        // Then distribute to payees
        for (uint256 i = 0; i < _payees.length; i++) {
            uint256 feeAmount = (_amounts[i] * platformFeePercentage) / 10000;
            uint256 payeeAmount = _amounts[i] - feeAmount;
            
            token.safeTransfer(_payees[i], payeeAmount);
            
            emit PaymentProcessed(
                _paymentIds[i],
                msg.sender,
                _payees[i],
                _tokenAddress,
                _amounts[i],
                feeAmount,
                _referenceHashes[i]
            );
        }
        
        // Transfer fees to fee collector
        if (totalFees > 0) {
            token.safeTransfer(feeCollector, totalFees);
        }
    }

    /**
     * @dev Verify a payment record exists
     * @param _paymentId ID of the payment to verify
     * @return exists Whether the payment exists
     * @return record The payment record
     */
    function verifyPayment(bytes32 _paymentId) 
        external 
        view 
        override
        returns (bool exists, PaymentRecord memory record) 
    {
        record = payments[_paymentId];
        exists = (record.paymentId != bytes32(0));
        return (exists, record);
    }

    /**
     * @dev Update platform fee percentage
     * @param _newFeePercentage New fee in basis points
     */
    function updatePlatformFee(uint256 _newFeePercentage) 
        external 
        onlyRole(ADMIN_ROLE) 
        override 
    {
        require(_newFeePercentage <= MAX_FEE, "Fee too high");
        platformFeePercentage = _newFeePercentage;
        emit FeeUpdated(_newFeePercentage);
    }

    /**
     * @dev Update fee collector address
     * @param _newFeeCollector New fee collector address
     */
    function updateFeeCollector(address _newFeeCollector) 
        external 
        onlyRole(ADMIN_ROLE) 
        override 
    {
        require(_newFeeCollector != address(0), "Invalid fee collector");
        feeCollector = _newFeeCollector;
        emit FeeCollectorUpdated(_newFeeCollector);
    }

    /**
     * @dev Set token registry address
     * @param _tokenRegistry New token registry address
     */
    function setTokenRegistry(address _tokenRegistry) external onlyRole(ADMIN_ROLE) {
        require(_tokenRegistry != address(0), "Invalid token registry");
        tokenRegistry = ITokenRegistry(_tokenRegistry);
    }
}