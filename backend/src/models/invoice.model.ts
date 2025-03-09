import mongoose from "mongoose";
import { v4 as uuidv4 } from "uuid";

const invoiceSchema = new mongoose.Schema(
  {
    invoiceNumber: {
      type: String,
      required: true,
      unique: true,
      default: () => `INV-${uuidv4().substring(0, 8).toUpperCase()}`,
    },
    creator: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    company: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Company",
      required: true,
    },
    client: {
      name: {
        type: String,
        required: true,
      },
      email: String,
      walletAddress: {
        type: String,
        required: true,
      },
      companyId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "Company",
      },
      address: {
        street: String,
        city: String,
        state: String,
        country: String,
        postalCode: String,
      },
    },
    issueDate: {
      type: Date,
      required: true,
      default: Date.now,
    },
    dueDate: {
      type: Date,
      required: true,
    },
    items: [
      {
        description: {
          type: String,
          required: true,
        },
        quantity: {
          type: Number,
          required: true,
        },
        unitPrice: {
          type: Number,
          required: true,
        },
        amount: {
          type: Number,
          required: true,
        },
        taxes: [
          {
            name: String,
            rate: Number,
            amount: Number,
          },
        ],
      },
    ],
    subtotal: {
      type: Number,
      required: true,
    },
    taxTotal: {
      type: Number,
      default: 0,
    },
    total: {
      type: Number,
      required: true,
    },
    currency: {
      fiat: {
        code: {
          type: String,
          required: true,
        },
        amount: {
          type: Number,
          required: true,
        },
      },
      crypto: {
        symbol: {
          type: String,
          required: true,
        },
        address: {
          type: String,
          required: true,
        },
        network: {
          type: String,
          required: true,
        },
        amount: {
          type: Number,
          required: true,
        },
      },
    },
    notes: String,
    attachments: [
      {
        filename: String,
        path: String,
        mimeType: String,
      },
    ],
    status: {
      type: String,
      enum: [
        "draft",
        "sent",
        "viewed",
        "partial",
        "paid",
        "overdue",
        "cancelled",
      ],
      default: "draft",
    },
    payment: {
      transactionHash: String,
      blockNumber: Number,
      paymentDate: Date,
      amount: Number,
      paymentId: String, // Reference to the on-chain payment ID
      paidBy: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    },
    isRecurring: {
      type: Boolean,
      default: false,
    },
    recurringSchedule: {
      frequency: {
        type: String,
        enum: ["weekly", "biweekly", "monthly", "quarterly", "yearly"],
      },
      nextInvoiceDate: Date,
      endDate: Date,
    },
    documentHash: String, // Hash stored on-chain for verification
    createdAt: {
      type: Date,
      default: Date.now,
    },
  },
  { timestamps: true }
);

const Invoice = mongoose.model("Invoice", invoiceSchema);
module.exports = Invoice;
