const router = require('express').Router();
const { register, login, getMe, updateProfile, changePassword } = require('../controllers/auth.controller');
const { authenticate } = require('../middleware/auth');
const validate = require('../middleware/validate');
const { authSchemas } = require('../validations');

router.post('/register', validate(authSchemas.register), register);
router.post('/login', validate(authSchemas.login), login);
router.get('/me', authenticate, getMe);
router.put('/me', authenticate, validate(authSchemas.updateProfile), updateProfile);
router.put('/password', authenticate, validate(authSchemas.changePassword), changePassword);

module.exports = router;
