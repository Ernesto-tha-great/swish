import mongoose from "mongoose";
import { v4 as uuidv4 } from "uuid";

const payrollSchema = new mongoose.Schema(
  {
    payrollId: {
      type: String,
      required: true,
      unique: true,
      default: () => `PAY-${uuidv4().substring(0, 8).toUpperCase()}`,
    },
    company: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Company",
      required: true,
    },
    creator: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    title: {
      type: String,
      required: true,
    },
    description: String,
    payPeriod: {
      startDate: {
        type: Date,
        required: true,
      },
      endDate: {
        type: Date,
        required: true,
      },
    },
    paymentDate: {
      type: Date,
      required: true,
    },
    recipients: [
      {
        user: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "User",
        },
        walletAddress: {
          type: String,
          required: true,
        },
        name: String,
        amount: {
          type: Number,
          required: true,
        },
        notes: String,
        status: {
          type: String,
          enum: ["pending", "processing", "paid", "failed"],
          default: "pending",
        },
        paymentDetails: {
          transactionHash: String,
          blockNumber: Number,
          paymentId: String,
        },
      },
    ],
    currency: {
      fiat: {
        code: {
          type: String,
          required: true,
        },
        totalAmount: {
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
        totalAmount: {
          type: Number,
          required: true,
        },
      },
    },
    status: {
      type: String,
      enum: [
        "draft",
        "scheduled",
        "processing",
        "completed",
        "partial",
        "cancelled",
      ],
      default: "draft",
    },
    isRecurring: {
      type: Boolean,
      default: false,
    },
    recurringSchedule: {
      frequency: {
        type: String,
        enum: ["weekly", "biweekly", "monthly", "quarterly"],
      },
      nextPaymentDate: Date,
      endDate: Date,
    },
    documentHash: String,
    notes: String,
    attachments: [
      {
        filename: String,
        path: String,
        mimeType: String,
      },
    ],
    createdAt: {
      type: Date,
      default: Date.now,
    },
  },
  { timestamps: true }
);

export default mongoose.model("Payroll", payrollSchema);
