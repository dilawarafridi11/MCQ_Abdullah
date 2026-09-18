const nodemailer = require('nodemailer');
const config = require('../config');

let _transporter = null;

const getTransporter = () => {
  if (_transporter) return _transporter;
  if (!config.email.enabled) {
    console.log('[Email] SMTP not configured — email disabled.');
    return null;
  }
  _transporter = nodemailer.createTransport({
    host: config.email.host,
    port: config.email.port,
    secure: config.email.secure,
    auth: {
      user: config.email.user,
      pass: config.email.pass,
    },
  });
  return _transporter;
};

const sendMail = async ({ to, subject, html, text, attachments }) => {
  const transporter = getTransporter();
  if (!transporter) {
    console.log('[Email] Skipped — SMTP not configured.');
    return null;
  }
  try {
    const info = await transporter.sendMail({
      from: config.email.from || config.email.user,
      to,
      subject,
      html: html || text,
      text: text || html,
      attachments,
    });
    console.log(`[Email] Sent: ${info.messageId}`);
    return info;
  } catch (err) {
    console.error('[Email] Send failed:', err.message);
    return null;
  }
};

module.exports = { sendMail };
