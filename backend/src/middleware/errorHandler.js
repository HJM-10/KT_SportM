const errorHandler = (err, req, res, next) => {
  if (res.headersSent) return next(err);
  const status = err.status || err.statusCode || 500;
  if (status >= 500) console.error(err.message);
  res.status(status).json({ success: false, message: status === 500 ? 'Internal server error' : err.message });
};
module.exports = errorHandler;
