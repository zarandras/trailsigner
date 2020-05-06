var express = require('express');
var router = express.Router();

/* GET home page. */
router.get('/', function(req, res, next) {
  res.render('index', { title: 'Express' });
});

/* GET webmap page. */
router.get('/webmap', function(req, res, next) {
  res.render('webmap');
});

module.exports = router;
