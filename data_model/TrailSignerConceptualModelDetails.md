# TrailSigner Conceptual Model Details

--------------------------

## GeoTrNet
Trail network graph.

Note: can be implemented as an aggregated snapshot of OpenStreetMap as well.

Remarks on operations and constraints: 
- The initial network graph is usually imported.
- The main user interface for managing the trail network is a desktop GIS application (preferably QGIS), connected to the database.
- If any modification is made, it generates a new version of the participating elements and is propagated to the related elements in other models, 
  so that they can be updated either automatically or - whenever required - by user intervention.
- TrailNode geometries are only modifiable together with the connected TrailSections via netLink. 
- Deletion of TrailNodes is only possible if exactly two TrailSections are connected via netLink, and they are merged, 
  or when no TrailSections are connected.
- Creating a TrailSection adds TrailNodes at its ends where no TrailNode exists.
- Splitting a TrailSection adds a TrailNode (pseudo-junction).
- Modifying the TrailSection geometry between endpoints is freely allowed, endpoints must be dragged together with the connected TrailNodes 
  and the other TrailSections connected to them.
- If a TrailSection endpoint needs to be detached from a TrailNode connected to other TrailSections, it must be split and the second part deleted.
- If a TrailSection is being split, its successors inherit the properties of it by default (with any geometry-dependent attributes recomputed), 
  and its successors replace its role in its relationships.
- If a TrailSection crosses or meets another TrailSection (level crossing), they must be split and a TrailNode added.
- Two TrailSections may be merged only when the connecting TrailNode has no other TrailSections or any other entities (Locations, POIs, signs etc.) connected, 
  and the two TrailSection has identical relationships with SimpleRoutes (containsTs) and Waymarking.
- The relation netLink is always consistent with the actual geometries: 
  a TrailSection has its start TrailNode at its first point of line geometry, and end TrailNode at its last point of geometry.
- The network of trails can be generated based on route geometries. It must be kept consistent with them, 
  either as a materialized view (split to a network, given the required or extra TrailNodes), 
  or the other way around, the route geometries can form a materialized view of the trail network if the containsTS relation is given.

### TrailNode

Nodes of the trail network graph.

Attributes:
- NodeCode (key): unique natural id in trail inventory (may be generated or not)
- Geom: point coordinates (possibly with Z coord)
- Altitude: number (or Z in geometry) - taken from DEM or manually updated
- NodeName (optional): if the node has a specific technical name used by the trail operators (not a public Location name) 
- OsmId: OpenStreetMap identifier (optional)

Remarks:
- If the OpenStreetMap data model is used for implementation, the TrailSection line geometries 
  can directly build on the TrailNode point geometries. In this case, all line string nodes become TrailNodes 
  of a "weak" type, TrailSections will refer to them in their order, and line geometries are derived as a materialized view  
- TrailNode table can also be defined as a view based on trail section endpoints, but in that case, identification becomes problematic.

### TrailSection

Actual trail sections, between two subsequent nodes of the trail network graph.

Attributes:
- SectionCode (key): unique natural id in trail inventory (may be generated or not)
- Geom: lineString coordinates (with Z)
- isOneWay: boolean (no navigation allowed in reverse direction - if allowed but there is no marking in reverse direction, it is handled by the SimpleRoutes)
- Status: existing / planned / dismissed / tempUnavailable 
- SectionName (optional): if the section has a specific name, not represented by the marked routes along it
- OsmId[]: OpenStreetMap identifier list (optional)
- TechDiff: technical difficulty grade (various systems, e.g. walk, hike, climb)
- Length: computed by geometry in 50 meters precision
- Ascent: computed by geometry (Z), in meters, in 10 meters precision
- Descent: computed by geometry (Z), in meters, in 10 meters precision
- MinAltitude: lowest point (m), computed by geometry
- MaxAltitude: highest point(m), computed by geometry
- WalkingTimeForward: computed by a respective formula based on the above attributes, or updated manually
- WalkingTimeBackward: computed by a respective formula based on the above attributes, or updated manually 
- isWalkingTimeManual: boolean (if manually updated)

Remarks:
- The trail sections have a default direction but they can be referenced by relationships in both direction (also reversed).
- For the above, a materialized view as union with reversed sections is needed, and that will be the referenced table by others
  OR: by separate db functions for getting geometry, ascent, descent, wtime by forward/backward reference modes

### netLink

Connections of trail nodes and sections to form the network graph.

Attributes:
- SectionCode: foreign key of TrailSection
- StartTrailNode: foreign key of TrailNode
- EndTrailNode: foreign key of TrailNode

Remarks: 
- Connects TrailNodes with TrailSections to form a routable network (see general remarks).
- Can be merged into the TrailSection entity type.
- Can be defined as a view based on endpoint geometries.

--------------------------

## RouLocNet
The route and location dataset, given as a "spaghetti model", but geometries aligned 
and topologized via the connections to GeoTrNet. Data exchange and mutual consistency strategy 
must be defined between RouLocNet and GeoTrNet for each actual implementation or deployment.

Note: can be implemented as an enhanced snapshot of OpenStreetMap as well. POIs are assumed to be taken from it.

Remarks on operations and constraints: 
- Locations must be explicitly added and connected to their TrailNodes. 
  A Location may optionally have a polygon or a point geometry as a centroid 
  which suggests existing, new or moved TrailNodes to be linked to it.
- If a TrailSection is not covered by a SimpleTrailRoute in either direction, 
  a pseudo-route can be generated so that the network is always fully covered by SimpleRoutes
  and can be referenced by LogFM and TourPres.

### Location

A named location related to the trails - can be assigned to nodes and location signs dynamically.

Attributes:
- FullName (key): unique full name
- ShortName: locally-referred, short name variant
- PoiFeaturePictos: list of pictograms of connected features (POI types)
- DefaultPointGeom: point, helps linking to nearby nodes (optional)
- DefaultPolyGeom: polygon alternative, helps linking to nearby nodes (optional)
- DefaultAltitude: altitude in meters, by default (optional)
- OsmId: OpenStreetMap identifier (optional)
 
### locAtTN

Connecting table with foreign keys of Location and TrailNode (many-to-many).
Location assignment can be recommended or generated, based on their geometries and the actual policy.

### POI

Points of interest relevant to the trail network. Taken from OpenStreetMap.

Attributes:
- OsmID (key): OpenStreetMap identifier
- Geom: Point geometry
- Name: POI name
- FeatureTypes: list of pictogram types or a single type of this POI 
- OsmTags: list of tags for this POI in OpenStreetMap

### poiAtTN

Connecting table with foreign keys of POI and TrailNode (many-to-many).
POI assignment can be recommended or generated, based on their geometries and the actual policy.

### SimpleRoute

Simple (designated) route of the network - with a specific trail mark and reference.
Note: a simple route may continue from a node only in one direction. 
If a route has loops, it must be decomposed accordingly.

- Route_code: route identifier (key)
- Geom: 3D line (Z coords), my be derived by section geometries
- RouteFullName: simple route name (alt.key, default: concatenation of RouteBrandName, RouteRef and RouteDirectionSpec - 
  or if RouteBrandName/RouteRef is empty, TrailMark and RouteDirectionSpec)
- RouteBrandName: the name of the larger brand / thematic network which this route forms or belongs to (e.g. Camino de Santiago)
- RouteRef: text, simple route number or acronym (e.g. E4/23, AT/12, etc.)
- RouteDirectionSpec: text referring to the direction/final destination of the trail (e.g. "northbound", "towards ...")
- Modality: hiking / ... 
- Network: lwn / rwn / nwn / iwn (local/regional/national/international)
- Trailmark: the mark acronym of this trail
- Operator: organization who coordinates development and maintenance of the trail
- OsmId: OpenStreetmap (super)relation identifier

Remark: c.f. ComplexRoute.

### revOf

A simple route is the reversal of another simple route.
Non-symmetric, RevRoutes are secondary reversed variants of Routes with primary direction.

- Route: foreign key of the primary simple route
- RevRoute: foreign key of the reversed simple route

Remark: may be merged into simpleRoute or a view with appropriate operations 
(seamless reference to a route and its reversal)

### containsTS

Which trail section belongs to which simple route.

- Route: foreign key to simple route
- TrailSection: foreign key to trail section
- IsTsReversed: boolean, whether the section is reversed
- OrderIndex: for ordering (number of trail section inside a route) 

--------------------------

## TourPres

Touristic presentation of the trail network for visitors.

Note: can be implemented as/inside a CMS as well, or a tourist guide framework.

### locRel

Relationships defined over locations.

- Loc1: Location key 1 (foreign key)
- Loc2: Location key 2 (foreign key)
- Relationship: hierarchy (contains) / variant (for multiple languages) / ...

### features (Location-POI)

Which POI is found in which location - for collecting their pictograms as location features.

- Loc: Location key (foreign key)
- Poi: POI key (foreign key)

### ComplexRoute

A complex route, possibly composed of several simple routes. Not necessarily a continuous route, 
may be a network itself, with different routes with roles explicitly related to each other. 

- RouteName: complex route name (key, default: concatenation of RouteBrandName, RouteRef, RouteDirectionSpec - 
  or if RouteBrandName/RouteRef is empty, TrailMark and RouteDirectionSpec)
- RouteBrandName: the name of the larger brand / thematic network which this route forms or belongs to (e.g. Camino de Santiago)
- RouteRef: text, route number or acronym (e.g. E4, AT, etc.)
- RouteDirectionSpec: text referring to the direction/final destination of the trail (e.g. "northbound", "towards ...")
- Modality: hiking / ... 
- Network: lwn / rwn / nwn / iwn (local/regional/national/international)
- Trailmark: the mark acronym of this trail
- Operator: organization who operates/coordinates development and maintenance of the trail
- OsmId: OpenStreetmap (super)relation identifier

Note: modeling of reversed variants:
must be explicitly created as separate complex routes 
and linked to a top-level route container by rtRel if needed 
(as 2 directions of the same top-level route).

### srOf

- ComplexRoute: complex route key (parent)
- SimpleRoute: simple route key (for containment)
- OrderIndex: ordering 

Remark: can be unified with rtRel

### Route

Generalized (designated) route: either simple or complex.

Remark: can be implemented in different ways 
according to cluster type translation to table schema.

### rtRel

Structural relationships between routes, expressed by the signage system or network concept

- Route1: 1st route - foreign key
- Route2: 2nd route - foreign key
- RelType: variantOf / sideTrailOf / directionOf

### TripRoute

Trips (trip routes) are precompiled paths in the trail network graph, along one or more routes or their parts,
which are recommended for visitors to go along as tours.

- TripName: Unique name
- User: who has created the route
- TechDiff: technical difficulty grade, computed by stages
- Length: computed by stages
- Ascent: computed by stages
- Descent: computed by stages
- MinAltitude: computed by stages
- MaxAltitude: computed by stages
- WalkingTime: computed by stages
- EndurDiff: endurance difficulty grade (various systems, aggregated from elevation gain and distance)

Note: if a CMS is used, it can be one of its content types.

### RouteStage

An arbitrary, continuous part of a simple route in the network, between nodes or remote locations

- Stage_Ref: unique identifier
- StartWpt: stage start, foreign key to RouStageWpt
- EndWpt: stage end, foreign key to RouStageWpt
- Geom: geometry, derived by sections (or manual if not in network)
- TechDiff: technical difficulty grade, computed by sections
- Length: computed by sections
- Ascent: computed by sections
- Descent: computed by sections
- MinAltitude: computed by sections
- MaxAltitude: computed by sections
- WalkingTime: computed by sections

Note: if a remote location is involved, stage geom and derived data must be entered manually 

Note: if a CMS is used, it can be one of its content types.

### RouStageWpt

- Wpt_Ref: unique identifier
- Location: named wpt, foreign key to location (optional) 
- TrailNode: node as wpt, foreign key to trail node (optional) 

Note: 
Location or TrailNode should not be null. 
If both are filled in, it refers to a node-location assignment.
If only location is filled, it refers to a remote location, 
not mapped in the current regional db, but part of a longer route.

### stgOf

Assignment of stages to trips (containment)

- TripRoute: foreign key
- RouteStage: foreign key
- OrderIndex: ordering (positive number)

### tripOf

Default trip(s) assigned to routes. A trail manager may compile one or more (featured) trip(s) for any route.

- Route: foreign key (ComplexRoute)
- Trip: foreign key (TripRoute)

### MediaContent

Any content (text description, photo, video, other image, PDF etc.) related to other items.

Note: if a CMS is used, it can be one of its content types.

### MapContent

A generated map (PDF or image) for a specific purpose.
 
Note: if a CMS is used, it can be one of its content types.

### attachedTo

Media content attachment to Routes, TripRoutes, RouteStages, Locations, POIs, TrailNodes

Remark: can be implemented in different ways 
according to cluster type translation to table schema.

--------------------------

## LogFM

Logical facility management part: trail signs dynamically composed of semantic relationships 
of trail routes, nodes and locations.

### LocationSign

A sign element declaration to show a location at its place, at one of the TrailNodes of that location.

- atTrailNode: foreign key to TrailNode - where this sign is (/to be) placed
- ofLocation: foreign key to Location - which location it refers to

The compound key of LocationSign is made of the two attributes above. 

Constraint for validity: 
- the 2 attributes must refer to a valid Location-TrailNode assignment according to locAtTN.

### DestSign

A generalization (cluster / disjoint union type) of LocationSign and RouteDestSign, without further attributes.

- Key: foreign key of RouteDestSign OR LocationSign (depending on the actual type).

### RouteDestSign

A sign element declaration to show a route destination sign at a trail node, 
i.e. that a specified location is reachable from that node via a specified route in its direction.

It is built up via structural recursion in the following way:
If the route is direct, the routeDestSign refers to a LocationSign at the destination, to specify the exact TrailNode.

- atTrailNode: foreign key to TrailNode - where this sign is (/to be) placed
- viaNextRoute: foreign key to SimpleRoute - the route to be followed next
- towardsNext: foreign key to DestSign - the sign which gives further information/direction 
(either a LocationSign if arrived, or another RouteDestSign along the indicated route 
if another route must be followed from a certain point towards the destination)
- toLocation: foreign key to the destination Location - either derived iteratively via the towardsNext chaining, 
or, optionally, specified explicitly and must be validated via a constraint.

The compound key of RouteDestSign is made of the 3 attributes (atTrailNode, viaNextRoute, towardsNext).
Note that the key will have a complex domain, since towardsNext has also a structurally recursive compound key.

Constraints for validity: 
- atTrailNode must be connected to a TrailSection contained by the SimpleRoute viaNextRoute.
- towardsNext's atTrailNode must also be connected to a TrailSection of viaNextRoute.
- atTrailNode must be followed by towardsNext's atTrailNode along viaNextRoute.
- if toLocation is specified explicitly, it must be equal to towardsNext's toLocation/atLocation.

### SignTrkData

The actually computed track data along the full path towards the destination, meant by a RouteDestSign.
It is used for the actual implementation of the sign - to derive what to be displayed there.
It is actually a materialized view over the current trail network setting.

- ofRouteDestSign: foreign key to the RouteDestSign
- DateTime: when this data was generated
- Destination-related attributes (copied from Location):
    - DestFullName: unique full name
    - DestShortName: locally-referred, short name variant
    - DestPoiFeaturePictos: list of pictograms of connected features (POI types)
    - DestDefaultAltitude: altitude in meters, by default (optional)
- viaNextRoute-related attributes (copied from SimpleRoute):
    - Route_code: route identifier
    - RouteFullName: simple route name (alt.key, default: concatenation of RouteBrandName, RouteRef and RouteDirectionSpec - 
      or if RouteBrandName/RouteRef is empty, TrailMark and RouteDirectionSpec)
    - RouteBrandName: the name of the larger brand / thematic network which this route forms or belongs to (e.g. Camino de Santiago)
    - RouteRef: text, simple route number or acronym (e.g. E4/23, AT/12, etc.)
    - RouteDirectionSpec: text referring to the direction/final destination of the trail (e.g. "northbound", "towards ...")
    - Modality: hiking / ... 
    - Network: lwn / rwn / nwn / iwn (local/regional/national/international)
    - Trailmark: the mark acronym of this trail
- Track(path)-related attributes (aggregated via the towardsNext signage chain):
    - TrkGeom: geometry, derived by sections
    - TechDiff: technical difficulty grade, computed by sections
    - Length: computed by sections
    - Ascent: computed by sections
    - Descent: computed by sections
    - WalkingTime: computed by sections

Track(path) data here are not rounded, rounding is made when the sign is being implemented (to avoid cumulated rounding errors)

### RouteSign

A sign element declaration to show the further direction of a route (without any destination written), 
at one of the TrailNodes along that route.

It is an additional type of sign for those intermediate junctions 
where only the continuation of a route needs to be marked and no destinations named.

- atTrailNode: foreign key to TrailNode - where this sign is (/to be) placed
- ofRoute: foreign key to a Route - which route it refers to

The compound key of RouteSign is made of the two attributes above. 

Constraint for validity: 
- atTrailNode must be connected to a TrailSection contained by the Route ofRoute.

### TrailSign

A generalization (cluster / disjoint union type) of DestSign and RouteSign.
This entity class is the subject of generative rule application (signpost logic).

- Key: foreign key of DestSign OR RouteSign (depending on the actual type).
- lastValidatedDate: when it was last validated against the trail network
- isDirty: boolean - the dirty flag indicates whether the TrailSign is actual 
(structurally-semantically validated against the current version of the trail network and its SignTrkData - if any - correct)

Remark: if any changes occur in the trail network (GeoTrNet or RouLocNet), 
all trail signs connected to the changed elements get the dirty flag as true.

### TrailSignRule

A table of the rules of signpost logics. Each generative rule is implemented as a database function/procedure, 
externally to this table. This collection is an explicit reference to them to make the sign implications traceable. 

- RuleCode: the identifier of the rule in the signpost logics.
- RuleName: a name of the rule (optional).
- RuleFuncName: the database subroutine name (function/procedure) of the implemented rule.
- Description: a textual description of the rule, what it actually does (optional).

### implies

An implication relation: which rule implies which generated trail signs.

- byRule: foreign key to TrailSignRule
- premiseSigns: foreign key array to TrailSigns as premises of the rule
- impliedSign: foreign key of the generated (implied) sign by that rule.

Note: may be merged into TrailSign/SuggestedSign/InvSign.

### SuggestedSign

A subtype of TrailSign, indicating its suggested status (and level) for implementation.
It may be explicitly chosen, or generated via the rules of signpost logics (see the implies relation).

- TrailSign: foreign key - which sign is suggested for implementation
- DateTime: when this suggestion was added/generated
- SLevel: suggested sign priority level (S_i) according to the signpost logic.
- SReason: a textual description about the reason why this sign is planned (optional).

Note: may be merged into TrailSign, keeping always the newest DateTime and lowest SLevel value.

### InvalidSign

- TrailSign: foreign key - which sign is suggested for implementation
- DateTime: when this suggestion was added/generated
- InvReason: a textual description about the reason why this sign is planned (optional).

Note: may be merged into TrailSign, keeping always the newest DateTime. Invalid signs can be deleted 
during a complete signage system validation and cleanup, if they are not actually implemented.
If an invalid sign is implemented (was implemented and becomes invalid due to trail network changes),
it must be kept until a proper resolution is made (removal / redesign / temporary condititon lifted).

--------------------------

## PhyFM

Physical facility management database part, i.e. inventory of trail signage assets.

Remark: can be implemented inside a facility management / inventory system and connected externally,
which should involve issue tickets, administration of implementation and maintenance works etc.

The entities represented here are the objects of such works, esp. Waymarking, Guidepost with SignBoard, InfoBoard and TrailMarker, 
and also ImplementedSign or DisplayedContent in a more sophisticated approach.

### ImplementedSign

A physically implemented sign with its actual data.

- SuggSign: a foreign key to a suggested sign in LogFM
- DateTime: when this data was entered
- User: who added this data
- Plus all attributes from SuggSign, with SignTrkData, 
  including reference (foreign) key to check for updates.

### pointsTo

In which direction (along which TrailSection) a sign (must) point, if it is a RouteDestSign.

- ImplementedSign: foreign key, which sign
- TrailSection: foreign key, to which section

Note. May be merged into ImplementedSign.

### ImplicitSign

Suggested but not actually implemented signs are marked here.
These are the "exceptions" of signs which should be implemented but actually not.
(for example: a location sign which is not necessary because another evidence shows where we are, 
or a destination sign generated twice for two routes following the same path)

- SuggSign: a foreign key to a suggested sign in LogFM
- DateTime: when this data was entered
- User: who added this data
- Reason: a description why this sign is not implemented

Note: may be merged into SuggSign if version management is in LogFM.

### Waymarking

Represents the set/sequence of waymarks (blazes, trail markers) along a section or in a node (junction)
without explicitly storing each waymark separately (c.f. TrailMarker).

- SimpleRoute: foreign key - which route this marking belongs to
- TrailSection: foreign key (optional): if it belongs to a section
- TrailNode: foreign key (optional): if it belongs to a node (junction)
(the above 3 forms the primary key)
- DateTime: when this data was entered/modified
- User: who added/modified this data
- LastWorkDate: when was it last installed/repaired/refurbished
- LastWorkCrew: who has last installed/repaired/refurbished it
- Status: existing / planned / dismissed / tempUnavailable 
- Condition: good / fair / poor / nonexistent
- StatusRemark: text describing any additional info
- FileFolder: location of related photos or other documentation 

### TrailMarker

A marker can be stored explicitly here, in addition to the Waymarking,
if it has a special type, condition or needs special treatment. 
(e.g. plate-form markers, or posts, or special arrow forms, or a critically important marker)

- ItemId: inventory item id (key)
- Geom: where this marker is
- DateTime: when this data was entered/modified
- User: who added/modified this data
- StatusRemark: text describing any info
- FileFolder: location of related photos, design plans or other documentation 

### markOf

Linking the TrailMarkers and ImplementedSigns to their Waymarking entities.

- ImplementedSign: foreign key to an ImplementedSign
- TrailMarker: foreign key to a TrailMarker (alternatively)
- Waymarking: foreign key to Waymarking, whose part is this marker

Note: can be merged into TrailMarker and ImplementedSign.

Note: an implemented sign is only added here if it has a special or integral role in the waymarking 
(e.g. no proper blazing exists)

### Guidepost

A guidepost is a holder of - possible multiple - sign boards.

- ItemId: inventory item id (key)
- Geom: where this guidepost is installed
- DateTime: when this data was entered/modified
- User: who added/modified this data
- LastWorkDate: when was it last installed/repaired/refurbished
- LastWorkCrew: who has last installed/repaired/refurbished it
- Status: existing / planned / dismissed / tempUnavailable 
- Condition: good / fair / poor / nonexistent
- StatusRemark: text describing any additional info
- FileFolder: location of related photos, design plans or other documentation 

### SignBoard

A sign board is a sign with  - possible multiple - trail route/location/destination signs.
It is mounted on a guidepost (signpost).

- ItemId: inventory item id (key)
- mountedOnGuidepost: guidepost id (foreign key)
- OrderIndex: where it is mounted on the guidepost
- DateTime: when this data was entered/modified
- User: who added/modified this data
- LastWorkDate: when was it last installed/repaired/refurbished
- LastWorkCrew: who has last installed/repaired/refurbished it
- Status: existing / planned / dismissed / tempUnavailable 
- Condition: good / fair / poor / nonexistent
- StatusRemark: text describing any additional info
- FileFolder: location of related photos, design plans or other documentation 

### InfoBoard

An info board is a complex board with possibly multiple information panels, some of them edited into one printout.

- ItemId: inventory item id (key)
- Geom: where this info board is installed
- DateTime: when this data was entered/modified
- User: who added/modified this data
- LastWorkDate: when was it last installed/repaired/refurbished
- LastWorkCrew: who has last installed/repaired/refurbished it
- Status: existing / planned / dismissed / tempUnavailable 
- Condition: good / fair / poor / nonexistent
- StatusRemark: text describing any additional info
- FileFolder: location of related photos, design plans or other documentation 

### rteInf

A linkage of an InfoBoard to a Route, 
i.e. whether it is a dedicated trailhead or other info sign of that trail route.  

- InfoBoard: foregin key to the info board
- ofRoute: foreign key to a simple or complex trail route

### displayedContent

Which media or map content is displayed/used on which info board.
It is for designing the info board and tracking any updates.

- InfoBoard: foreign key to the info board
- MediaContent: foreign key to the media content
- MapContent: foreign key to the map content (alternatively)

### displayedSign

Which implemented sign (trail route, destination or location sign) 
is displayed/used on which sign board (signpost/arrow), 
or alternatively, info board.
It is for designing the sign/info board and tracking any updates.

- ImplementedSign: foreign key to the sign displayed
- onSignBoard: foreign key to the sign board
- onInfoBoard: foreign key to the info board (alternatively)
- OrderIndex: where the sign is placed (order, or for info boards, may be more complex)

--------------------------

