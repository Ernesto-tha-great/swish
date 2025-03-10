import Invoice from "../models/invoice.model";
import User from "../models/user.model";
import Company from "../models/company.model";
import blockchainService from "../blockchain/contract.service";
import crypto from "crypto";
import logger from "../utils/logger";

class InvoiceService {
  async createInvoice(invoiceData: any, userId: string) {
    try {
      const user = await User.findById(userId);
      if (!user) {
        throw new Error("User not found");
      }

      const company = await Company.findById(invoiceData.company);
      if (!company) {
        throw new Error("Company not found");
      }

      // Create invoice in database
      const invoice = new Invoice({
        ...invoiceData,
        creator: userId,
        status: "draft",
      });

      // Generate document hash for blockchain verification
      const documentContent = JSON.stringify({
        invoiceNumber: invoice.invoiceNumber,
        company: invoice.company,
        client: invoice.client,
        issueDate: invoice.issueDate,
        dueDate: invoice.dueDate,
        items: invoice.items,
        total: invoice.total,
        currency: invoice.currency,
      });

      const documentHash = crypto
        .createHash("sha256")
        .update(documentContent)
        .digest("hex");

      invoice.documentHash = documentHash;
      await invoice.save();

      // Register document hash on blockchain
      if (invoiceData.status !== "draft") {
        const documentType = 0; // 0 = Invoice in our enum
        await blockchainService.registerDocument(
          documentHash,
          documentType,
          invoice.invoiceNumber
        );
      }

      return invoice;
    } catch (error) {
      logger.error(`Invoice creation error: ${error.message}`);
      throw error;
    }
  }

  // Get invoice by ID
  async getInvoiceById(invoiceId, userId) {
    try {
      const invoice = await Invoice.findById(invoiceId)
        .populate("creator", "firstName lastName email")
        .populate("company", "name logo");

      if (!invoice) {
        throw new Error("Invoice not found");
      }

      // Verify document on blockchain if it has a hash
      if (invoice.documentHash) {
        const verificationResult = await blockchainService.verifyDocument(
          invoice.documentHash
        );
        (invoice as any).verification = verificationResult;
      }

      return invoice;
    } catch (error) {
      logger.error(`Get invoice error: ${error.message}`);
      throw error;
    }
  }

  // Update invoice status
  async updateInvoiceStatus(invoiceId, status, paymentDetails: any = null) {
    try {
      const invoice = await Invoice.findById(invoiceId);
      if (!invoice) {
        throw new Error("Invoice not found");
      }

      invoice.status = status;

      if (paymentDetails) {
        invoice.payment = paymentDetails;
      }

      await invoice.save();
      return invoice;
    } catch (error) {
      logger.error(`Update invoice status error: ${error.message}`);
      throw error;
    }
  }

  // Process invoice payment
  async processInvoicePayment(invoiceId, payerWalletAddress) {
    try {
      // Find invoice and populate the company to access its properties
      const invoice = await Invoice.findById(invoiceId).populate("company");
      if (!invoice) {
        throw new Error("Invoice not found");
      }

      if (invoice.status === "paid") {
        throw new Error("Invoice already paid");
      }

      // Type assertion to tell TypeScript this is a populated document
      const company = invoice.company as any;

      // Generate a unique payment ID
      const paymentId = crypto.randomUUID();

      // Create reference hash (links payment to invoice)
      const referenceData = JSON.stringify({
        invoiceId: invoice._id,
        invoiceNumber: invoice.invoiceNumber,
        amount: invoice.currency?.crypto?.amount || 0,
        timestamp: Date.now(),
      });

      const referenceHash = crypto
        .createHash("sha256")
        .update(referenceData)
        .digest("hex");

      // Get crypto details with fallbacks
      const cryptoAddress =
        invoice.currency && invoice.currency.crypto
          ? invoice.currency.crypto.address || ""
          : "";
      const cryptoAmount =
        invoice.currency && invoice.currency.crypto
          ? invoice.currency.crypto.amount || 0
          : 0;

      // Process payment on blockchain
      const paymentResult = await blockchainService.processPayment(
        paymentId,
        company.walletAddress,
        cryptoAddress,
        cryptoAmount,
        referenceHash
      );

      if (!paymentResult.success) {
        throw new Error(`Payment failed: ${paymentResult.error}`);
      }

      // Update invoice with payment details
      const paymentDetails = {
        transactionHash: paymentResult.transactionHash,
        blockNumber: paymentResult.blockNumber,
        paymentDate: new Date(),
        amount: invoice.currency?.crypto?.amount || 0,
        paymentId: paymentId,
        paidBy: payerWalletAddress,
      };

      await this.updateInvoiceStatus(invoiceId, "paid", paymentDetails);
      return paymentResult;
    } catch (error) {
      logger.error(`Process invoice payment error: ${error.message}`);
      throw error;
    }
  }

  // List invoices with filters
  async listInvoices(filters, userId) {
    try {
      let query = {};

      // Basic filters
      if (filters.status) {
        query = { ...query, status: filters.status };
      }

      if (filters.company) {
        query = { ...query, company: filters.company };
      }
      // Date range filters
      if (filters.startDate && filters.endDate) {
        query = {
          ...query,
          issueDate: {
            $gte: new Date(filters.startDate),
            $lte: new Date(filters.endDate),
          },
        };
      }

      // Amount range filters
      if (filters.minAmount || filters.maxAmount) {
        const totalQuery: any = {};

        if (filters.minAmount) {
          totalQuery.$gte = filters.minAmount;
        }
        if (filters.maxAmount) {
          totalQuery.$lte = filters.maxAmount;
        }

        query = {
          ...query,
          total: totalQuery,
        };
      }

      // Get user's companies
      const userCompanies = await Company.find({
        $or: [{ ownerId: userId }, { "members.userId": userId }],
      }).select("_id");

      const companyIds = userCompanies.map((company) => company._id);
      // Add company filter
      query = { ...query, company: { $in: companyIds } };

      const invoices = await Invoice.find(query)
        .populate("creator", "firstName lastName")
        .populate("company", "name")
        .sort({ createdAt: -1 });

      return invoices;
    } catch (error) {
      logger.error(`List invoices error: ${error.message}`);
      throw error;
    }
  }
}

export default new InvoiceService();
