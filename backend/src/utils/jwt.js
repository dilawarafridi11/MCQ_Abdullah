const jwt = require('jsonwebtoken');
const config = require('../config');

const signToken = (userId, role, shopId) =>
  jwt.sign({ id: userId, role, shopId }, config.jwtSecret, {
    expiresIn: config.jwtExpiresIn,
  });

const verifyToken = (token) => jwt.verify(token, config.jwtSecret);

const sanitizeIp = (ip) => ip || 'unknown';

const parseDeviceInfo = (req) => {
  const userAgent = req.headers['user-agent'] || 'unknown';
  const platform =
    req.headers['x-platform'] ||
    (userAgent.includes('Android')
      ? 'Android'
      : userAgent.includes('iPhone') || userAgent.includes('iPad')
        ? 'iOS'
        : 'Web');
  const appVersion = req.headers['x-app-version'] || 'unknown';
  return {
    platform,
    userAgent,
    appVersion,
  };
};

module.exports = { signToken, verifyToken, sanitizeIp, parseDeviceInfo };
