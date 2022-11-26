---- SQL operations copied from the first database which is being replaced. 
---- TODO: These operations need to be updated and extended.


select *, (select tn."Name" from trail_node_centroid tn order by ds."location" <#> tn.geom limit 1) from direction_sign ds
where ds.is_destination_sign and ds.is_dirty

select * from direction_sign ds left join trail_node_centroid tn on ST_DWithin(ds."location", tn.geom, .005)
where ds.is_destination_sign and ds.is_dirty

select * from direction_sign ds join direction_sign ds_next on (ds.next_direction_sign_id = ds_next.id) where ds.is_dirty and not ds_next.is_dirty;

---------------------------------------------------

--Get track data for dirty locations:

CREATE OR REPLACE PROCEDURE public.trail_compute_dirty_destinations_proc()
 LANGUAGE plpgsql
AS $$
begin
  insert into sign_track_data (destination_text, distance_exact, time_exact, direction_sign_id)
  (select distinct on (ds.id) 
	tn."Name" as destination_text, 
	--TO_char(round( ST_Distance(ST_Transform(ds."location",32634), ST_Transform(tn.geom,32634))::numeric ,-2)/1000,'9990D9') || ' km' as distance_text_rounded,
	ST_Distance(ST_Transform(ds."location",32634), ST_Transform(tn.geom,32634))::numeric as distance_exact,
	0 as time_exact,
	ds.id as direction_sign_id
  --	ST_Distance(ds."location", tn.geom)
  from direction_sign ds, trail_node_centroid tn
  where ds.is_destination_sign and ds.is_dirty
  and ST_DWithin(ds."location", tn.geom, .005)
  ORDER by ds.id, ST_Distance(ds."location", tn.geom));

  --clear dirty flag
  update direction_sign ds
  set is_dirty = false
  where ds.is_destination_sign and ds.is_dirty
  and exists (select * from trail_node_centroid tn where ST_DWithin(ds."location", tn.geom, .005));

  commit;
 end;
$$;

-- TO CALL:
call trail_compute_dirty_destinations_proc (); 


------

-- Get track data for dirty direction signs
CREATE OR REPLACE PROCEDURE public.trail_compute_dirty_direction_signs_proc()
 LANGUAGE plpgsql
AS $$
begin
insert into sign_track_data (destination_text, trailmarks_next, trailmarks_extension, distance_exact, direction_sign_id)
 select 
	dstd_next.destination_text as destination_text,
	--... as distance_text_rounded,
	array[coalesce(tr.jel, tr."osmc:symbol")] as trailmarks_next,
	case when (cardinality(dstd_next.trailmarks_next)>0 and coalesce(tr.jel, tr."osmc:symbol")<>dstd_next.trailmarks_next[1])
		then concat('>', dstd_next.trailmarks_next[1], dstd_next.trailmarks_extension)
		else dstd_next.trailmarks_extension 
	end as trailmarks_extension,
	trail_compute_distance(ds."location", dstd_next."location", --st_makeline(array_agg(trline.geom)))
        tr.geom)
        + dstd_next.distance_exact as distance_exact,
	ds.id as direction_sign_id
 from 
	direction_sign ds 
	join direction_sign_track_data dstd_next on (ds.next_direction_sign_id = dstd_next.id and dstd_next.sign_track_data_status = 'computed')
	join --trail_route
		trail_route_line
		tr on (ds.next_trail_id = tr.id)
	--cross join lateral st_dump(st_linemerge(tr.geom)) trline
 where ds.is_dirty and not dstd_next.is_dirty
 --group by ds.id, dstd_next.id, tr.id, dstd_next.destination_text, tr.jel, dstd_next.trailmarks_next, dstd_next.trailmarks_extension, dstd_next."location", dstd_next.distance_exact
 ;

 --clear dirty flag
 update direction_sign ds
 set is_dirty = false
 where not ds.is_destination_sign and ds.is_dirty
 and exists (select * from direction_sign ds_next where ds.next_direction_sign_id = ds_next.id and not ds_next.is_dirty);

 commit;
end;
$$;

-- TO CALL:
call trail_compute_dirty_direction_signs_proc (); 

-----
CREATE OR REPLACE FUNCTION public.trail_compute_distance(from_point geometry, to_point geometry, trail_route geometry) 
returns float
AS $$
	BEGIN
		RETURN ST_Length(
			ST_Transform(
				ST_LineSubstring(
					trail_route, 
					ST_LineLocatePoint(trail_route, from_point), 
					ST_LineLocatePoint(trail_route, to_point)
				),
				32634
			)
		);
	END;
$$ LANGUAGE plpgsql
;
-----

--drop view trail_route_line;
create materialized view trail_route_line as
select id, st_makeline(array_agg(trline.geom)) as geom, osm_id, osm_type, jel, name, network, "osmc:symbol", symbol, route, "type", "ref", layer, fid_2
from trail_route tr
cross join lateral st_dump(st_linemerge(tr.geom)) trline
group by tr.id, osm_id, osm_type, jel, name, network, "osmc:symbol", symbol, route, "type", "ref", layer, fid_2;

-- TO REFRESH:
refresh materialized view trail_route_line;

-----


-------

-- add missing signposts where there is another signpost but a previous one not written:
CREATE OR REPLACE PROCEDURE public.trail_add_missing_signposts_proc ()
 LANGUAGE plpgsql
AS $$
begin
  insert into direction_sign ("location", next_direction_sign_id, next_trail_id, realization_reason)
  select distinct --ds.id as other_sign_id, 
	ds."location", --ds1.id as previous_sign_id, 
	ds2.id as next_direction_sign_id, 
	tr.id as trail_route_id,
	'newly_generated_intermediate_sign'::enum_realization_reason as realization_reason
  from direction_sign ds join
	trail_route_line tr on ST_DWithin(ds."location", tr.geom, .0005)
	join direction_sign ds1 on (
		ds1.next_trail_id = tr.id and 
		ST_LineLocatePoint(tr.geom, ds."location") > ST_LineLocatePoint(tr.geom, ds1."location")
	) 
	join direction_sign ds2 on (
		ds1.next_direction_sign_id = ds2.id and 
		ST_LineLocatePoint(tr.geom, ds."location") < ST_LineLocatePoint(tr.geom, ds2."location")
	)
  where (tr.id, ds2.id) not in (
	select dss.next_trail_id, dss.next_direction_sign_id from direction_sign dss
	where ST_DWithin(ds."location", dss."location", .0005) 
  );
  commit;
end;
$$;

-- TO CALL:
call trail_add_missing_signposts_proc (); 

--then execute the computation for generating sign_track_data
call trail_compute_dirty_direction_signs_proc ();

--------

-- recommendations : what is signposted at the next place(s)

create table direction_sign_recommended (
	"location" geometry(point), 
	next_direction_sign_id integer references direction_sign(id), 
	next_trail_id integer references trail_route(id),
    recommendation_priority numeric, -- currently the distance of nearest similar sign along trail
	unique ("location", next_direction_sign_id, next_trail_id)
);

-- get recommendations :
create or replace function trail_generate_recommended_signs()
    returns table (
	    "location" geometry(point), 
	    next_direction_sign_id integer, 
	    next_trail_id integer,
	    nearest_distance_where_signed numeric
    )
language sql
as $$
select "location", next_direction_sign_id, next_trail_id, nearest_distance_where_signed from (
  select --ds.id as other_sign_id, 
	ds."location", --ds1.id as previous_sign_id, 
		-- if it is a destination sign, there is no next dir., if there is, take the next dir sign, because we remain on the same route
		-- (no marking changes recommended for now yet! - otherwise, we must have recommended with ds2.id as the next direction sign)
	coalesce(ds2.next_direction_sign_id, ds2.id) as next_direction_sign_id, 
	tr.id as next_trail_id,
	min(ST_LineLocatePoint(tr.geom, ds2."location") - ST_LineLocatePoint(tr.geom, ds."location"))::numeric as nearest_distance_where_signed
  from direction_sign ds join
	trail_route_line tr on ST_DWithin(ds."location", tr.geom, .0005)
	join direction_sign ds2 on (
		ST_DWithin(ds2."location", tr.geom, .0005) and
		ST_LineLocatePoint(tr.geom, ds."location") < ST_LineLocatePoint(tr.geom, ds2."location") 
		and (ds2.is_destination_sign or ds2.next_trail_id = tr.id)
	)
  where (tr.id, coalesce(ds2.next_direction_sign_id, ds2.id)) not in (
	select dss.next_trail_id, coalesce(dss.next_direction_sign_id,-1) from direction_sign dss
	where ST_DWithin(ds."location", dss."location", .0005) 
  ) 
  --OPTIONAL: only for those trails that are already involved:
	and tr.id in (select distinct next_trail_id from direction_sign)
  group by ds."location", coalesce(ds2.next_direction_sign_id, ds2.id), tr.id
  order by "location", min(ST_LineLocatePoint(tr.geom, ds2."location") - ST_LineLocatePoint(tr.geom, ds."location"))
) a
$$;


-- add recommendations to direction_sign_recommended table:
create or replace procedure trail_generate_recommended_signs_proc () 
language sql
as $$
insert into direction_sign_recommended ("location", next_direction_sign_id, next_trail_id, recommendation_priority)
select (trail_generate_recommended_signs()).*;
$$

-- move recommendations into real table:
create or replace procedure trail_apply_recommended_signs_proc () 
language plpgsql
as $$
begin
  insert into direction_sign ("location", next_direction_sign_id, next_trail_id, realization_reason)
    select "location", next_direction_sign_id, next_trail_id,
         'newly_generated_recommended_sign'::enum_realization_reason as realization_reason from direction_sign_recommended; 
  delete from direction_sign_recommended;
  commit;
end;
$$;


-- TO CALL:
call trail_generate_recommended_signs_proc ();
select * from direction_sign_recommended;
call trail_apply_recommended_signs_proc ();
--then compute dirties:
call trail_compute_dirty_direction_signs_proc ();

--------

-- OVERVIEW FUNCTIONS:

--- what to signpost where:
-- signposts along the routes
create or replace function trail_get_signposts_at_locations() 
	returns table ("location" geometry, destination_text text, distance_text text, trailmarks_text text, ds_id integer, next_direction_sign_id integer, next_trail_id integer) 
language sql
as $$
select 
	"location",
	destination_text, 
	to_char(round(distance_exact,-2)/1000,'9990D9') || ' km' as distance_text, 
	concat(trailmarks_next[1], trailmarks_extension) as trailmarks_text, 
	id as ds_id, next_direction_sign_id, next_trail_id
from direction_sign_track_data
order by "location", next_trail_id, distance_exact
;
$$;

-- TO CALL:
select trail_get_signposts_at_locations();

-----------

-- signposts along the routes
create or replace function trail_get_signposts_along_routes() 
	returns table (trail_id integer, dist_along_trail numeric, "location" geometry, direction_signs text[]) 
language sql
as $$
select 
	tr.id as trail_id,
	round(trail_compute_distance_fromstart(dstd."location", tr.geom)::numeric,-1)/1000 as dist_along_trail,
	"location",
	--dstd.id,
	array_agg(
		concat(
			' ', destination_text, 
			case when round(distance_exact,-2)>0 
				then concat(' ', to_char(round(distance_exact,-2)/1000,'90D9') || ' km ')
				else ' '
			end,
			concat(coalesce(trailmarks_next[1],''), coalesce(trailmarks_extension,''))
		) order by distance_exact
	) as direction_signs--, 
	--next_direction_sign_id, next_trail_id
from direction_sign_track_data dstd 
	join trail_route_line tr on ((dstd.next_trail_id is null or dstd.next_trail_id = tr.id) and ST_DWithin(dstd."location", tr.geom, .0005))
where tr.id in (select next_trail_id from direction_sign)
group by tr.id, trail_compute_distance_fromstart(dstd."location", tr.geom), "location"
order by tr.id, trail_compute_distance_fromstart(dstd."location", tr.geom)
$$;

-- TO CALL:
select trail_get_signposts_along_routes();

--------

-- add/update destination ids - should be a trigger on table direction_sign
-- TODO

--------

--- mismatch: close-locations as destination signs, with extra route snippets (as in excel), with no marks but shortest-paths (next_trail_id is null)
---         by-the-way: there is now a mismatch because destination signs contain distances to centroid and it might not be correct, centroids must be moved to proper places (e.g. Vaskapu) 
---                and such distances must be computed based on trail network
--- handle coinciding route sections with trailmark sets..., proper trailmark set handling for having intermediate parallel sections 

--- extra: shortest-path handling for signposts without next_trail_id specification
--- ... etc...

--- TODO: dirty flag clearance should be based on trigger (inserting computed track data), not on explicit update

-- TODO: handling invalidity, e.g. points not on line, no nexts exist, modified tracks etc.
-- TODO: handling dirty - if anything is modified; computation instead of existing or insert new

-- TODO: improving recommendations
--      current drawbacks: no placemarkers (destination signs) generated for centroids, all signposted destinations along a route is recommended (even the branching ones when pre-signed),
--              almost-there places omitted (e.g. Vaskapu for Z), no branching recommendations - if there were, stupid ones must have been omitted (e.g. alog the same route reversed, 
--              "coming back", going to the same place with longer route - a place with the shortest route and/or along a simple trail should be recommended only
--               - for that destination_ids need to be populated)
--       - destination sign at each node (centroid) onto routes, 
--            with added priority classes - more than one to each point! [based on qualitative properties as well, so we can include route/subnetwork-specific preferendes]
--       - recommend everywhere the next signposted destinations (only one of each priority class, incl.destination signs) and their (2/3) nexts in chain
--              except where 2 or more changes are, and the trail is reversed, and the destination is already written in a direct way (instead of indirect)

--------

--geojson export of used trails
create or replace function trail_export_trails_geojson () returns table (geojson jsonb) 
language sql
as 
$$
SELECT jsonb_build_object(
    'type',     'FeatureCollection',
    'features', jsonb_agg(feature)
)
FROM (
  SELECT jsonb_build_object(
    'type',       'Feature',
    'id',         id,
    'geometry',   ST_AsGeoJSON(geom)::jsonb,
    'properties', to_jsonb(row) - 'gid' - 'geom'
  ) AS feature
  FROM (SELECT * FROM trail_route_line where id in (select next_trail_id from direction_sign)) row) features;
$$;

-- TO CALL:
select trail_export_trails_geojson();
-- called from http://localhost/~ajmolnar/routes_geojson.php

