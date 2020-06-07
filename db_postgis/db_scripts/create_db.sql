
--CREATE DATABASE trailsigner;
--\CONNECT trailsigner

CREATE EXTENSION postgis;
CREATE EXTENSION btree_gist;


-- ======== GeoTrNet SCHEMA ========

-- Remark: types are immutable as new variants get new ids with the same natural key, only time_validity is updated.

-- DROP TABLE trail_node;
CREATE TABLE trail_node (
	id serial PRIMARY KEY NOT NULL,
	time_validity tstzrange NOT NULL DEFAULT tstzrange(now(), 'infinity', '[)'),
	node_code varchar NOT NULL ,--DEFAULT concat('tn',to_char(id,'00009')), -- actual key with time_validity
	geom geometry(POINTZ, 4326) NOT NULL,
	altitude integer NULL ,--DEFAULT st_z(geometry),
	node_name text NULL,
	osm_id integer NULL,
	EXCLUDE USING gist (node_code with =, time_validity WITH &&)
);
CREATE INDEX trail_node_geom_index ON trail_node USING gist (geom);
CREATE INDEX trail_node_code_index ON trail_node (node_code);
-- note: (same as old trail_node table, extended)

-- DROP TYPE ts_status_enum;
CREATE TYPE ts_status_enum AS enum ('existing', 'planned', 'closed', 'tempClosed');

-- DROP TABLE trail_section;
CREATE TABLE trail_section (
	id serial PRIMARY KEY NOT NULL,
	time_validity tstzrange NOT NULL DEFAULT tstzrange(now(), 'infinity', '[)'),
    section_code varchar NOT NULL ,--DEFAULT concat('ts',to_char(id,'00009')), -- actual key with time_validity
	geometry geometry(LINESTRINGZ, 4326) NOT NULL,
    is_one_way boolean NOT NULL DEFAULT false,
    status ts_statud_enum NOT NULL DEFAULT 'existing',
    section_name text NULL,
    osm_id text NULL, -- comma-separated
    tech_diff text NULL, -- various systems, e.g. walk, hike, climb)
    length integer ,-- DEFAULT round(st_3dlength(geometry)/50)*50,
    ascent integer, -- TODO: DEFAULT: computed by geometry (Z), in meters, in 10m precision
    descent integer, --TODO: DEFAULT: computed by geometry (Z), in meters, in 10m precision
    wtime_fw integer, -- TODO: computed by a respective formula based on the above attributes, or updated manually
    wtime_bw integer, -- TODO: computed by a respective formula based on the above attributes, or updated manually
    is_wt_manual boolean NOT NULL DEFAULT false, -- TODO: trigger change of wtime_fw/bw and set to true
	EXCLUDE USING gist (section_code with =, time_validity WITH &&)
);
CREATE INDEX trail_section_geom_index ON trail_section USING gist (geom);
CREATE INDEX trail_section_code_index ON trail_section (section_code);
-- remark: each section has a direction in the db, but in fact is usually bidirectional
-- note: (same as old trail_section table, but without waymarking info)

-- note: netLink can be defined as a view
-- TODO netLink as a view

-- TODO: materialized view as union with reversed sections, and that will be the referenced table by others
--       OR write functions for getting geometry, ascent, descent, wtime by fw/bw modes (reversed and non-reversed)

-- remark: alternative approach: define these tables as (materialized) views on the RouLocNet schema or vica versa

-- TODO: add an operation for updating nodes if anything changes - add new nodes if necessary, move old nodes
-- TODO: add triggers to prevent invalid modifications (see conceptual model details)

-- ======== RouLocNet SCHEMA ========

-- Remark: types are immutable as new variants get new ids with the same natural key, only time_validity is updated.

-- DROP TABLE location;
CREATE TABLE location (
	id serial PRIMARY KEY NOT NULL,
	time_validity tstzrange NOT NULL DEFAULT tstzrange(now(), 'infinity', '[)'),
	full_name varchar(255) NOT NULL, -- actual key with time_validity
	short_name varchar(32) NULL ,--DEFAULT full_name,
    poi_feature_pictos text NULL,
	default_point_geom geometry(POINT, 4326) NULL,
	default_poly_geom geometry(POLYGON, 4326) NULL,
    default_altitute integer NULL,
    osm_id integer UNIQUE NULL,
    CHECK (default_point_geom IS NULL OR default_poly_geom IS NULL),
	EXCLUDE USING gist (full_name with =, time_validity WITH &&)
);
CREATE INDEX location_point_index ON trail_location USING gist (default_point_geom);
CREATE INDEX location_poly_index ON trail_location USING gist (default_poly_geom);
CREATE INDEX location_name_index ON trail_location (full_name);
CREATE INDEX location_short_name_index ON trail_location (short_name);
-- remark: the location table can be created from named trail node clusters.
--         The geom is derived or informal, and only acts as an anchor to display the location on the map,
--         and to recommend linkage to new nearby nodes
--         as the actual places of location signs are attached to trail nodes directly.

-- TODO: POI table & import, or reference to OpenStreetMap

--DROP TABLE simple_route
CREATE TABLE simple_route (
	id serial PRIMARY KEY NOT NULL,
	time_validity tstzrange NOT NULL DEFAULT tstzrange(now(), 'infinity', '[)'),
	rou_code varchar(255) NOT NULL, -- actual key with time_validity
	geom geometry(MULTILINESTRINGZ, 4326) NULL,
	isrevof_rou_code varchar(255) NULL ,-- REFERENCES simple_route(route_code), -- reversed of route_code - secondary route
    rou_full_name: varchar NOT NULL,
        -- unique with time_validity,
        -- default: concatenation of RouteBrandName, RouteRef and RouteDirectionSpec ...
        -- ...or if RouteBrandName/RouteRef is empty, TrailMark and RouteDirectionSpec
    rou_brandname varchar NULL, -- (e.g. Camino de Santiago)
    rou_ref varchar NULL, -- (e.g. E4/23, AT/12, etc.)
    rou_dirspec varchar NULL, -- e.g. "northbound", "towards ..."
    modality varchar NOT NULL DEFAULT 'hiking',
    network varchar NULL, --lwn / rwn / nwn / iwn (local/regional/national/international)
	trailmark varchar NULL,
    operator varchar NULL,
	osm_id varchar NULL,
	EXCLUDE USING gist (route_code with =, time_validity WITH &&)
);

-- note: containsTS relation can be defined as a view based on geometry
-- TODO define containsTS
-- TODO define poiAtTN, locAtTN tables - or defined as views based on geometry and partially location signs

-- remark: alternative approach: define these tables as (materialized) views on the GeoTrNet schema

-- ======== TourPres SCHEMA ========

-- TODO: for signposting, locRel, features, rouRel are necessary relations

-- TODO specify and implement this part of the DB - possibly with/part of a CMS.

-- ======== LogFM SCHEMA ========

-- Note: The TrailSign subtypes are merged into one type, by partial cluster-combination and union approach
-- and surrogate key introduction, keeping only the supertype since each instance of the subtypes is a member of the supertype

-- DROP TYPE ts_status_enum;
CREATE TYPE trail_sign_type_enum AS enum ('route_sign', 'route_dest_sign', 'location_sign');
CREATE OR REPLACE FUNCTION is_dest_sign(trail_sign_type) RETURNS boolean
    AS 'select $1 in (''route_dest_sign'', ''location_sign'')'
    LANGUAGE SQL
    IMMUTABLE
    RETURNS NULL ON NULL INPUT;

-- DROP TABLE trail_sign;
CREATE TABLE trail_sign (
	id serial PRIMARY KEY NOT NULL,
    at_node_code varchar NOT NULL REFERENCES trail_node(node_code),
    trail_sign_type trail_sign_type_enum,
    via_rou_code varchar REFERENCES simple_route(rou_code) CHECK (via_rou_code IS NULL OR trail_sign_type != 'location_sign'),
    to_loc_full_name varchar REFERENCES location(full_name) CHECK (to_loc_full_name IS NULL OR trail_sign_type != 'route_sign'),
        -- or: if trail_sign_type = 'route_dest_sign' then defaulted to towards_next_rds_id . to_loc_full_name
    tw_next_rds_id integer REFERENCES trail_sign(id) CHECK (tw_next_rds IS NOT NULL OR trail_sign_type != 'route_dest_sign'), -- foreign key to next DestSign
    --UNIQUE (at_node_code, trail_sign_type, via_rou_code, to_loc_full_name, tw_next_rds), -- ensures uniqueness across the whole structure by induction
    is_dirty boolean DEFAULT true,
    is_invalid boolean DEFAULT false,
    s_level integer DEFAULT 0, -- suggested sign priority level (S_i) according to the signpost logic.
    status_reason text, -- suggestion or invalidity reason
    status_set_at timestamp with time zone, -- suggestion or invalidity datetime
    validated_at timestamp with time zone -- last validated (structurally verified and sign track data generated/updated)
);
CREATE INDEX trail_sign_node_idx ON trail_sign(at_node_code);
CREATE INDEX trail_sign_route_idx ON trail_sign(via_route_code);
CREATE INDEX trail_sign_to_loc_idx ON trail_sign(to_loc_full_name);
CREATE INDEX trail_sign_towards_idx ON trail_sign(tw_next_rds_id);
CREATE INDEX trail_sign_s_level_idx ON trail_sign(s_level);

--TODO Further constraints for validity:
-- at_node_code is along via_rou_code (if the latter is not null).
-- (at_node_code, to_location) is in table locAtTN if trail_sign_type = 'location_sign'
-- tw_next_rds_id.at_node_code is along via_rou_code (if the latter is not null) and is followed by this.at_node_code along that route.
-- tw_next_rds_id.to_loc_full_name = this.to_loc_full_name (if both are not null).

-- DROP TABLE sign_trk_data;
CREATE TABLE sign_trk_data (
    trail_sign_id NOT NULL REFERENCES trail_sign(id),
    generated_at timestamp with time zone NOT NULL DEFAULT NOW(),

--- Destination-related attributes - NOT copied from Location, only referenced due to proper historization
    to_location_id integer references location(id), -- NULL iff route_sign
--        dest_full_name varchar(255) NULL, -- actual location key with time_validity
--        dest_short_name varchar(32) NULL,
--        dest_poi_feature_pictos text NULL,
--        dest_default_altitute integer NULL,

--- viaNextRoute-related attributes - NOT copied from SimpleRoute, only referenced due to proper historization
    via_rou_id integer references simple_route(id), -- NULL iff location_sign
--        rou_code varchar(255) NULL, -- actual simple_route key with time_validity
--        rou_full_name: varchar NULL,
--        rou_brandname varchar NULL,
--        rou_ref varchar NULL,
--        rou_dirspec varchar NULL,
--        modality varchar NULL
--        network varchar NULL,
--        trailmark varchar NULL,

--- Track(path)-related attributes: -- NOT NULL iff route_dest_sign
        trk_geom geometry(LINESTRINGZ, 4326) NULL,
        tech_diff text NULL,
        length integer NULL,
        ascent integer NULL,
        descent integer NULL,
        wtime_fw integer NULL,
);
CREATE INDEX sign_trk_data_idx ON sign_trk_data(trail_sign_id);

-- Note: in the original model and its fullest content, it applies only to route_dest_sign-s.
--   It is extended for general trail_signs due to the practicality of storing the actual id (variant)
--   of the location or route the sign refers to, in its current form at the time of signage validation.
--   This will act as a basis for comparison when invalidity or track data is checked for implemented signs

-- TODO: sign track data generation: ids added according to actually valid variants of locations/simple_routes,
-- TODO: aggregated sign track data cumulated via the towardsNext signage chain,
--  and summarized along the via_rou section btw trail_sign_id's at_node_code and tw_next_rds_id.trail_sign_id

-- DROP TABLE trail_sign_rule;
CREATE TABLE trail_sign_rule (
    rule_code varchar(32) NOT NULL PRIMARY KEY,
    rule_name text NULL,
    rule_func_name varchar NOT NULL, -- function/procedure name of the implemented rule
    description text NULL
);

-- TODO: implement rules as db functions/procedures and the whole implication process in general
--    based on the adaptation of the old partial experimental implementations

-- DROP TABLE tsr_implies;
CREATE TABLE tsr_implies (
    by_rule_code varchar NOT NULL REFERENCES trail_sign_rule(rule_code),
    premise_trail_sign_ids integer[] NOT NULL --REFERENCES trail_sign(id) each
    implied_trail_sign_id integer NOT NULL REFERENCES trail_sign(id)
);

-- ======== PhyFM SCHEMA ========

-- TODO specify and implement this part of the DB - possibly with/part of a full-fledged inventory system.

-- TODO for waymarking, fm data needs to be imported from the old trail_section table

