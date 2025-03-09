// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/PaymentProcessor.sol";
import "../src/TokenRegistry.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1_000_000 * 10**decimals());
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract PaymentProcessorTest is Test {
    PaymentProcessor public paymentProcessor;
    TokenRegistry public tokenRegistry;
    MockToken public mockToken;
    
    address public admin = address(1);
    address public paymentManager = address(2);
    address public payer = address(3);
    address public payee = address(4);
    address public feeCollector = address(5);
    
    bytes32 public constant PAYMENT_MANAGER_ROLE = keccak256("PAYMENT_MANAGER_ROLE");
    uint256 public constant FEE_PERCENTAGE = 250; // 2.5%
    
    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy mock token
        mockToken = new MockToken();
        
        // Deploy token registry
        tokenRegistry = new TokenRegistry();
        
        // Add mock token to registry
        tokenRegistry.addToken(
            "MTK",
            address(mockToken),
            18,
            1 * 10**18 // 1 MTK min transfer
        );
        
        // Deploy payment processor
        paymentProcessor = new PaymentProcessor(
            feeCollector,
            FEE_PERCENTAGE,
            address(tokenRegistry)
        );
        
        // Grant roles
        paymentProcessor.grantRole(PAYMENT_MANAGER_ROLE, paymentManager);
        
        // Mint tokens to payer
        mockToken.mint(payer, 10_000 * 10**18);
        
        vm.stopPrank();
    }
    
    function testProcessPayment() public {
        vm.startPrank(payer);
        
        bytes32 paymentId = keccak256("payment-1");
        uint256 amount = 100 * 10**18; // 100 tokens
        bytes32 referenceHash = keccak256("invoice-1-reference");
        
        // Approve tokens
        mockToken.approve(address(paymentProcessor), amount);
        
        // Process payment
        paymentProcessor.processPayment(
            paymentId,
            payee,
            address(mockToken),
            amount,
            referenceHash,
            "" // No signature needed since we're the payer
        );
        
        // Check payment record
        (bool exists, IPaymentProcessor.PaymentRecord memory record) = 
            paymentProcessor.verifyPayment(paymentId);
        
        assertTrue(exists);
        assertEq(record.payer, payer);
        assertEq(record.payee, payee);
        assertEq(record.tokenAddress, address(mockToken));
        assertEq(record.amount, amount);
        assertEq(record.referenceHash, referenceHash);
        
        // Calculate fee
        uint256 feeAmount = (amount * FEE_PERCENTAGE) / 10000;
        uint256 payeeAmount = amount - feeAmount;
        
        // Check balances
        assertEq(mockToken.balanceOf(payee), payeeAmount);
        assertEq(mockToken.balanceOf(feeCollector), feeAmount);
        
        vm.stopPrank();
    }
    
    function testProcessBatchPayment() public {
        vm.startPrank(paymentManager);
        
        // Setup batch payment data
        bytes32[] memory paymentIds = new bytes32[](3);
        paymentIds[0] = keccak256("batch-payment-1");
        paymentIds[1] = keccak256("batch-payment-2");
        paymentIds[2] = keccak256("batch-payment-3");
        
        address[] memory payees = new address[](3);
        payees[0] = payee;
        payees[1] = address(6);
        payees[2] = address(7);
        
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100 * 10**18; // 100 tokens
        amounts[1] = 150 * 10**18; // 150 tokens
        amounts[2] = 200 * 10**18; // 200 tokens
        
        bytes32[] memory referenceHashes = new bytes32[](3);
        referenceHashes[0] = keccak256("invoice-1");
        referenceHashes[1] = keccak256("invoice-2");
        referenceHashes[2] = keccak256("invoice-3");
        
        uint256 totalAmount = 450 * 10**18; // 450 tokens
        
        // Switch to payer to approve tokens
        vm.stopPrank();
        vm.startPrank(payer);
        mockToken.approve(address(paymentProcessor), totalAmount);
        
        // Switch back to payment manager
        vm.stopPrank();
        vm.startPrank(paymentManager);
        
        // Process batch payment (as payment manager on behalf of payer)
        vm.prank(payer); // We need to be the payer for the transfer
        paymentProcessor.processBatchPayment(
            paymentIds,
            payees,
            address(mockToken),
            amounts,
            referenceHashes
        );
        
        // Calculate fees
        uint256 feeAmount1 = (amounts[0] * FEE_PERCENTAGE) / 10000;
        uint256 feeAmount2 = (amounts[1] * FEE_PERCENTAGE) / 10000;
        uint256 feeAmount3 = (amounts[2] * FEE_PERCENTAGE) / 10000;
        uint256 totalFees = feeAmount1 + feeAmount2 + feeAmount3;
        
        // Check balances
        assertEq(mockToken.balanceOf(payees[0]), amounts[0] - feeAmount1);
        assertEq(mockToken.balanceOf(payees[1]), amounts[1] - feeAmount2);
        assertEq(mockToken.balanceOf(payees[2]), amounts[2] - feeAmount3);
        assertEq(mockToken.balanceOf(feeCollector), totalFees);
        
        vm.stopPrank();
    }
    
    function testUpdateFeePercentage() public {
        vm.prank(admin);
        paymentProcessor.updatePlatformFee(300); // Update to 3%
        
        assertEq(paymentProcessor.platformFeePercentage(), 300);
    }
    
    function testUpdateFeeCollector() public {
        address newFeeCollector = address(8);
        
        vm.prank(admin);
        paymentProcessor.updateFeeCollector(newFeeCollector);
        
        assertEq(paymentProcessor.feeCollector(), newFeeCollector);
    }
}