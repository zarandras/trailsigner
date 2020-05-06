
--CREATE DATABASE trailsigner;
--\CONNECT trailsigner

CREATE EXTENSION postgis;

-- ======== GeoTrNet SCHEMA ========

-- DROP TABLE trail_node;
CREATE TABLE trail_node (
	id serial PRIMARY KEY NOT NULL,
	geometry geometry(POINTZ, 4326) NOT NULL--,
	--node_code varchar UNIQUE NOT NULL DEFAULT concat('tn',to_char(id,'00009'))
);
CREATE INDEX trail_node_index ON trail_node USING gist (geometry);
-- note: (same as old trail_node table)

-- DROP TABLE trail_section;
CREATE TABLE trail_section (
	id serial PRIMARY KEY NOT NULL,
	geometry geometry(LINESTRINGZ, 4326) NOT NULL,
	waytype text NULL--,
	--section_code varchar UNIQUE NOT NULL DEFAULT concat('ts',to_char(id,'00009'))
);
CREATE INDEX trail_section_index ON trail_section USING gist (geometry);
-- remark: each section has a direction in the db, but in fact is usually bidirectional
-- note: (same as old trail_section table, but without waymarking info)

-- note: netLink can be defined as a view
-- TODO ...

-- remark: alternative approach: define these tables as (materialized) views on the RouLocNet schema

-- ======== RouLocNet SCHEMA ========

-- DROP TABLE trail_location;
CREATE TABLE trail_location (
	id serial PRIMARY KEY NOT NULL,
	"name" varchar(255) UNIQUE NOT NULL,
	ui_geometry geometry(POINT, 4326) NULL--,
	--short_name varchar(32) NULL DEFAULT "name",
	--altitute integer,
	--feature_poi_types varchar[]
);
CREATE INDEX trail_location_index ON trail_location USING gist (ui_geometry);
CREATE INDEX trail_location_name_index ON trail_location ("name");
-- remark: the trail_location table is created from named trail node clusters.
--         The geometry is derived and only acts as an anchor to display the location on the map,
--         as the actual locations of location signs are attached to trail nodes.

-- TODO POI table & import, or reference to OpenStreetMap

--DROP TABLE trail_route
CREATE TABLE trail_route (
	id serial PRIMARY KEY NOT NULL,
	geom geometry(MULTILINESTRINGZ, 4326) NULL,
	osm_id varchar NULL,
	"name" varchar NOT NULL,
	is_reversed boolean NULL,
	--short_name varchar(32) NULL,
	route_modality varchar NULL, -- hiking
	"network" varchar NULL,        -- lwn, rwn, nwn, iwn
	trailmark varchar NULL,
	route_ref varchar NULL,
	CONSTRAINT trail_route_name_key UNIQUE (name, is_reversed)
);

-- note: containsTS, poiAtTN, locAtTN relations can be defined as views
-- TODO ...

-- remark: alternative approach: define these tables as (materialized) views on the GeoTrNet schema

-- ======== TourPres SCHEMA ========

-- TODO: for signposting, locRel, features, rouRel are necessary relations

-- TODO ...

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

-- ======== PhyFM SCHEMA ========

-- TODO ...

-- TODO for waymarking, fm data needs to be imported from the old trail_section table

