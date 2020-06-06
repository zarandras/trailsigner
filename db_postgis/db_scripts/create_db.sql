
--CREATE DATABASE trailsigner;
--\CONNECT trailsigner

CREATE EXTENSION postgis;
CREATE EXTENSION btree_gist;


-- ======== GeoTrNet SCHEMA ========

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

-- DROP TYPE trail_section_...;
CREATE TYPE ts_status_enum AS enum ('existing', 'planned', 'closed', 'tempClosed');
;
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

-- DROP TABLE dest_sign;
CREATE TABLE dest_sign (
	id serial PRIMARY KEY NOT NULL,
    at_node_id int NOT NULL REFERENCES trail_node(id),
	is_loc_sign bool NOT NULL DEFAULT false,

	via_route_id int NULL REFERENCES trail_route(id),
	towards_dest_sign_id int NULL REFERENCES dest_sign(id),

    loc_sign_location_id NULL REFERENCES trail_location(id),

    s_priority int NOT NULL DEFAULT 0
);
CREATE INDEX dest_sign_node_idx ON dest_sign(at_node_id);
CREATE INDEX dest_sign_route_idx ON dest_sign(via_route_id);
CREATE INDEX dest_sign_towards_idx ON dest_sign(towards_dest_sign_id);
CREATE INDEX dest_sign_s_priority_idx ON dest_sign(s_priority);

-- TODO ...
--### LocationSign

--### DestSign

--### RouteDestSign

--### SignTrkData

--### RouteSign

--### TrailSign

--### TrailSignRule

--### implies

--### SuggSign

--### InvSign

-- ======== PhyFM SCHEMA ========

-- TODO specify and implement this part of the DB - possibly with/part of a full-fledged inventory system.

-- TODO for waymarking, fm data needs to be imported from the old trail_section table

