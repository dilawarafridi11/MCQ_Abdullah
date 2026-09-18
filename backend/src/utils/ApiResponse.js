class ApiResponse {
  constructor(statusCode, message = 'Success', data = null) {
    this.statusCode = statusCode;
    this.message = message;
    this.data = data;
    this.success = true;
  }

  static ok(message = 'Success', data = null) {
    return new ApiResponse(200, message, data);
  }

  static created(message = 'Created', data = null) {
    return new ApiResponse(201, message, data);
  }
}

module.exports = ApiResponse;
