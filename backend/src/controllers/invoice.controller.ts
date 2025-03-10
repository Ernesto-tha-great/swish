import { validationResult } from "express-validator";
import invoiceService from "../services/invoice.service";

exports.createInvoice = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const invoice = await invoiceService.createInvoice(req.body, req.user.id);

    res.status(201).json({
      success: true,
      data: invoice,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
};

exports.getInvoice = async (req, res) => {
  try {
    const invoice = await invoiceService.getInvoiceById(
      req.params.id,
      req.user.id
    );

    res.status(200).json({
      success: true,
      data: invoice,
    });
  } catch (error) {
    res.status(error.message === "Invoice not found" ? 404 : 500).json({
      success: false,
      error: error.message,
    });
  }
};

exports.updateInvoiceStatus = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { status } = req.body;
    const invoice = await invoiceService.updateInvoiceStatus(
      req.params.id,
      status
    );

    res.status(200).json({
      success: true,
      data: invoice,
    });
  } catch (error) {
    res.status(error.message === "Invoice not found" ? 404 : 500).json({
      success: false,
      error: error.message,
    });
  }
};

exports.processPayment = async (req, res) => {
  try {
    const result = await invoiceService.processInvoicePayment(
      req.params.id,
      req.user.walletAddress
    );

    res.status(200).json({
      success: true,
      data: result,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
};

exports.listInvoices = async (req, res) => {
  try {
    const filters = {
      status: req.query.status,
      company: req.query.company,
      startDate: req.query.startDate,
      endDate: req.query.endDate,
      minAmount: req.query.minAmount,
      maxAmount: req.query.maxAmount,
    };

    const invoices = await invoiceService.listInvoices(filters, req.user.id);

    res.status(200).json({
      success: true,
      count: invoices.length,
      data: invoices,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
};

// exports.deleteInvoice = async (req, res) => {
//   try {
//     await invoiceService.deleteInvoice(req.params.id, req.user.id);

//     res.status(200).json({
//       success: true,
//       message: 'Invoice deleted successfully'
//     });
//   } catch (error) {
//     res.status(error.message === 'Invoice not found' ? 404 : 500).json({
//       success: false,
//       error: error.message
//     });
//   }
// };

exports.markAsSent = async (req, res) => {
  try {
    const invoice = await invoiceService.updateInvoiceStatus(
      req.params.id,
      "sent"
    );

    res.status(200).json({
      success: true,
      data: invoice,
    });
  } catch (error) {
    res.status(error.message === "Invoice not found" ? 404 : 500).json({
      success: false,
      error: error.message,
    });
  }
};
