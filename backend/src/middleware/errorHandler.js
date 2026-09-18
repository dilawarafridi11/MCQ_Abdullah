const ApiError = require('../utils/ApiError');

const notFound = (req, res, next) => {
  next(new ApiError(404, `Route not found: ${req.originalUrl}`));
};

const errorHandler = (err, req, res, next) => {
  let error = err;

  if (err.name === 'ValidationError') {
    const messages = Object.values(err.errors).map((e) => e.message);
    error = new ApiError(400, messages[0], messages);
  } else if (err.code === 11000) {
    const field = Object.keys(err.keyValue || {})[0] || 'field';
    error = new ApiError(409, `Duplicate value for ${field}.`);
  } else if (err.name === 'CastError') {
    error = new ApiError(400, `Invalid value for ${err.path}.`);
  } else if (err.name === 'ImmutableDocumentError') {
    error = new ApiError(403, err.message);
  } else if (!(err instanceof ApiError)) {
    error = new ApiError(500, err.message || 'Internal server error');
  }

  if (process.env.NODE_ENV !== 'test') {
    console.error(`${error.statusCode || 500} - ${error.message}`);
  }

  return res.status(error.statusCode || 500).json({
    success: false,
    message: error.message,
    errors: error.errors || undefined,
  });
};

module.exports = { notFound, errorHandler };
