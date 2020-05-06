var express = require('express');
var router = express.Router();
var queries = require('../db_postgis/queries');

/* GET users listing. */
router.get('/',
  queries.getSignposts
  //res.send(queries.getSignposts(req,res));
);

module.exports = router;
