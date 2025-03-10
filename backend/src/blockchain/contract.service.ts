import { ethers } from "ethers";
import PaymentProcessorABI from "../abis/PaymentProcessor.json";
import RecurringPaymentABI from "../abis/RecurringPayment.json";
import DocumentRegistryABI from "../abis/DocumentRegistry.json";
import logger from "../utils/logger";
import { config } from "dotenv";

// Ensure environment variables are loaded
config();

type TransactionResult = {
  success: boolean;
  transactionHash?: string;
  blockNumber?: number;
  error?: string;
};

type DocumentVerificationResult = {
  success?: boolean;
  exists?: boolean;
  isValid?: boolean;
  timestamp?: number;
  registeredBy?: string;
  error?: string;
};

class BlockchainService {
  private provider: ethers.JsonRpcProvider;
  private wallet: ethers.Wallet;
  private paymentProcessor: ethers.Contract;
  private recurringPayment: ethers.Contract;
  private documentRegistry: ethers.Contract;

  constructor() {
    const rpcUrl = process.env.MORPH_RPC_URL;
    const privateKey = process.env.WALLET_PRIVATE_KEY;

    if (!rpcUrl || !privateKey) {
      throw new Error(
        "Missing required environment variables for blockchain service"
      );
    }

    this.provider = new ethers.JsonRpcProvider(rpcUrl);
    this.wallet = new ethers.Wallet(privateKey, this.provider);

    const paymentProcessorAddress = process.env.PAYMENT_PROCESSOR_ADDRESS;
    const recurringPaymentAddress = process.env.RECURRING_PAYMENT_ADDRESS;
    const documentRegistryAddress = process.env.DOCUMENT_REGISTRY_ADDRESS;

    if (
      !paymentProcessorAddress ||
      !recurringPaymentAddress ||
      !documentRegistryAddress
    ) {
      throw new Error("Missing contract addresses in environment variables");
    }

    this.paymentProcessor = new ethers.Contract(
      paymentProcessorAddress,
      PaymentProcessorABI.abi,
      this.wallet
    );

    this.recurringPayment = new ethers.Contract(
      recurringPaymentAddress,
      RecurringPaymentABI.abi,
      this.wallet
    );

    this.documentRegistry = new ethers.Contract(
      documentRegistryAddress,
      DocumentRegistryABI.abi,
      this.wallet
    );
  }

  // Process a payment on-chain
  async processPayment(
    paymentId: string,
    payee: string,
    tokenAddress: string,
    amount: number,
    referenceHash: string
  ): Promise<TransactionResult> {
    try {
      const tx = await this.paymentProcessor.processPayment(
        ethers.encodeBytes32String(paymentId),
        payee,
        tokenAddress,
        ethers.parseUnits(amount.toString(), 18),
        ethers.encodeBytes32String(referenceHash)
      );

      const receipt = await tx.wait();
      logger.info(`Payment processed: ${receipt.hash}`);

      return {
        success: true,
        transactionHash: receipt.hash,
        blockNumber: receipt.blockNumber,
      };
    } catch (error: any) {
      logger.error(`Payment processing error: ${error.message}`);
      return {
        success: false,
        error: error.message,
      };
    }
  }

  // Register a document hash on-chain
  async registerDocument(
    documentHash: string,
    documentType: number,
    reference: string
  ): Promise<TransactionResult> {
    try {
      const tx = await this.documentRegistry.registerDocument(
        ethers.encodeBytes32String(documentHash),
        documentType,
        reference
      );

      const receipt = await tx.wait();
      logger.info(`Document registered: ${receipt.hash}`);

      return {
        success: true,
        transactionHash: receipt.hash,
        blockNumber: receipt.blockNumber,
      };
    } catch (error: any) {
      logger.error(`Document registration error: ${error.message}`);
      return {
        success: false,
        error: error.message,
      };
    }
  }

  // Set up a recurring payment
  async createRecurringPayment(
    paymentId: string,
    payee: string,
    tokenAddress: string,
    amount: number,
    frequency: number,
    firstPaymentDue: number,
    referenceId: string
  ): Promise<TransactionResult> {
    try {
      const tx = await this.recurringPayment.createRecurringPayment(
        ethers.encodeBytes32String(paymentId),
        payee,
        tokenAddress,
        ethers.parseUnits(amount.toString(), 18),
        frequency,
        firstPaymentDue,
        ethers.encodeBytes32String(referenceId)
      );

      const receipt = await tx.wait();
      logger.info(`Recurring payment created: ${receipt.hash}`);

      return {
        success: true,
        transactionHash: receipt.hash,
        blockNumber: receipt.blockNumber,
      };
    } catch (error: any) {
      logger.error(`Recurring payment error: ${error.message}`);
      return {
        success: false,
        error: error.message,
      };
    }
  }

  // Verify a document exists on-chain
  async verifyDocument(
    documentHash: string
  ): Promise<DocumentVerificationResult> {
    try {
      const result = await this.documentRegistry.verifyDocument(
        ethers.encodeBytes32String(documentHash)
      );

      return {
        exists: result.exists,
        isValid: result.isValid,
        timestamp: result.documentData.timestamp.toNumber(),
        registeredBy: result.documentData.registeredBy,
      };
    } catch (error: any) {
      logger.error(`Document verification error: ${error.message}`);
      return {
        success: false,
        error: error.message,
      };
    }
  }
}

// Export as singleton
export default new BlockchainService();
