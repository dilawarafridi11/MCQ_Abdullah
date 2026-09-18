const mongoose = require('mongoose');
const config = require('./index');

const connectDB = async () => {
  const conn = await mongoose.connect(config.mongoUri);
  console.log(`MongoDB connected: ${conn.connection.host}`);
  return conn;
};

module.exports = connectDB;
