const Pool = require('pg').Pool

const pool = new Pool({
    host: 'localhost',
    port: 5433,
    database: 'ajmolnar',
    user: 'ajmolnar',
    password: '5ohe94',
})

module.exports = {
    pool,
}
