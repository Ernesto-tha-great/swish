import mongoose from "mongoose";

const companySchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, "Company name is required"],
      trim: true,
    },
    walletAddress: {
      type: String,
      required: [true, "Wallet address is required"],
      unique: true,
    },
    email: {
      type: String,
      required: [true, "Email is required"],
      unique: true,
    },
    phone: String,
    website: String,
    logo: String,
    address: {
      street: String,
      city: String,
      state: String,
      country: String,
      postalCode: String,
    },
    taxIdentification: {
      type: String,
      unique: true,
      sparse: true,
    },
    industry: String,
    acceptedTokens: [
      {
        symbol: String,
        address: String,
        network: String,
        isDefault: {
          type: Boolean,
          default: false,
        },
      },
    ],
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    members: [
      {
        userId: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "User",
        },
        role: {
          type: String,
          enum: ["admin", "member", "accountant", "viewer"],
          default: "member",
        },
        permissions: {
          createInvoices: {
            type: Boolean,
            default: false,
          },
          approvePayments: {
            type: Boolean,
            default: false,
          },
          manageUsers: {
            type: Boolean,
            default: false,
          },
          viewReports: {
            type: Boolean,
            default: false,
          },
        },
      },
    ],
    createdAt: {
      type: Date,
      default: Date.now,
    },
  },
  { timestamps: true }
);

export default mongoose.model("Company", companySchema);
