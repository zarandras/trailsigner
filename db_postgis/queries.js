
const pool = require('./db_conn_pool').pool

const getSignposts = (request, response, next) => {
    pool.query(

        //'SELECT st_y(location) as lat, st_x(location) as lon, count(*) as count, array_agg(id) as ids FROM direction_sign_track_data group by location',

        'SELECT jsonb_build_object(\n' +
        '    \'type\',     \'FeatureCollection\',\n' +
        '    \'features\', jsonb_agg(feature)\n' +
        ')\n' +
        'FROM (\n' +
        '  SELECT jsonb_build_object(\n' +
        '    \'type\',       \'Feature\',\n' +
        //'    \'id\',      id,\n' +
        '    \'geometry\',   ST_AsGeoJSON(location)::jsonb,\n' +
        '    \'properties\', to_jsonb(row) - \'location\'\n' +
        '  ) AS feature\n' +
        'FROM (\n' +
        '     SELECT location, count(*) as count, array_agg(id) as ids, array_agg(concat(\'&gt; \', destination_text, \' \', round(distance_exact/1000, 1), \'km \', trailmarks_next[1], trailmarks_extension, \'<br>\')) as txts FROM direction_sign_track_data group by location\n' +
        ') row) features',

        (error, results) => {
            if (error) {
                throw error
            }
            response.status(200).json(results.rows)
        })
}
module.exports = {
    getSignposts,
}
