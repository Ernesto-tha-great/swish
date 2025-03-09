// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/PaymentProcessor.sol";
import "../src/RecurringPayment.sol";
import "../src/DocumentRegistry.sol";
import "../src/TokenRegistry.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy TokenRegistry first
        TokenRegistry tokenRegistry = new TokenRegistry();
        
        // Deploy PaymentProcessor with TokenRegistry address
        address feeCollector = vm.envAddress("FEE_COLLECTOR");
        uint256 platformFeePercentage = 250; // 2.5%
        PaymentProcessor paymentProcessor = new PaymentProcessor(
            feeCollector,
            platformFeePercentage,
            address(tokenRegistry)
        );
        
        // Deploy RecurringPayment with PaymentProcessor address
        RecurringPayment recurringPayment = new RecurringPayment(
            address(paymentProcessor)
        );
        
        // Deploy DocumentRegistry
        DocumentRegistry documentRegistry = new DocumentRegistry();
        
        // Setup roles
        // Grant PAYMENT_MANAGER_ROLE to RecurringPayment contract
        paymentProcessor.grantRole(
            keccak256("PAYMENT_MANAGER_ROLE"),
            address(recurringPayment)
        );
        
        // Add some initial tokens to the registry 
        // USDC on Morph (placeholder address)
        tokenRegistry.addToken(
            "USDC",
            0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174, // Placeholder
            6,
            1000000 // 1 USDC min transfer
        );
        
        // USDT on Morph (placeholder address)
        tokenRegistry.addToken(
            "USDT",
            0xc2132D05D31c914a87C6611C10748AEb04B58e8F, // Placeholder
            6,
            1000000 // 1 USDT min transfer
        );
        
        // DAI on Morph (placeholder address)
        tokenRegistry.addToken(
            "DAI",
            0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063, // Placeholder
            18,
            1000000000000000000 // 1 DAI min transfer
        );
        
        console.log("Deployed TokenRegistry at:", address(tokenRegistry));
        console.log("Deployed PaymentProcessor at:", address(paymentProcessor));
        console.log("Deployed RecurringPayment at:", address(recurringPayment));
        console.log("Deployed DocumentRegistry at:", address(documentRegistry));
        
        vm.stopBroadcast();
    }
}