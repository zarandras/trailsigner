CREATE EXTENSION dblink;

insert into trail_node select id, geometry
from dblink('dbname=ajmolnar port=5433','SELECT id, geometry FROM trail_node') as t(id int, geometry geometry);
insert into trail_section select id, geometry, waytype from dblink('dbname=ajmolnar port=5433','SELECT id, geometry, waytype FROM trail_section') as t(id int, geometry geometry, waytype text);

insert into trail_location select *
from dblink('dbname=ajmolnar port=5433','SELECT id, "Name", geom FROM trail_node_centroid WHERE "Name" != ''()''') as t(id int, "name" text, ui_geometry geometry);

insert into trail_route SELECT id, wkb_geometry, osm_id, "name", case when layer = 'Reversed' then true else false end, route, network, jel, "ref" FROM merged_routes_without_ivv
