# TrailSigner Conceptual Model Details

--------------------------

## GeoTrNet
Trail network graph.

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

Attributes:
- NodeCode (key): unique natural id in trail inventory (may be generated or not)
- Geometry: point coordinates
- NodeName (optional): if the node has a specific technical name used by the trail operators (not a public Location name) 
- Altitude: number (or Z in geometry) - taken from DEM or manually updated

Remarks:
- If the OpenStreetMap data model is used for implementation, the TrailSection line geometries 
  can directly build on the TrailNode point geometries. 
- Can also be defined as a view based on trail section endpoints, but in that case, identification becomes problematic.

### TrailSection

Attributes:
- SectionCode (key): unique natural id in trail inventory (may be generated or not)
- Geometry: lineString coordinates (with Z)
- isOneWay: boolean (no navigation allowed in reverse direction - if allowed but there is no marking in reverse direction, it is handled by the SimpleRoutes)
- Status: existing / planned / closed / tempClosed
- SectionName (optional): if the section has a specific name, not represented by the marked routes along it
- TechDiff: technical difficulty grade (various systems, e.g. walk, hike, climb)
- Length: computed by geometry in 50 meters precision
- Ascent: computed by geometry (Z), in meters
- Descent: computed by geometry (Z), in meters
- WalkingTimeForward: computed by a respective formula based on the above attributes, or updated manually
- WalkingTimeBackward: computed by a respective formula based on the above attributes, or updated manually 
- isWalkingTimeManual: boolean (if manually updated)

Remarks:
- The trail sections have a default direction but they can be referenced by relationships in both direction (also reversed).

### netLink

Attributes:
- SectionCode: foreign key of TrailSection
- StartTrailNode: foreign key of TrailNode
- EndTrailNode: foreign key of TrailNode

Remarks: 
- Connects TrailNodes with TrailSections to form a routable network (see general remarks).
- Can be merged into the TrailSection entity type.
- Can be defined as a view.

--------------------------

## RouLocNet
The route and location dataset, given as a "spaghetti model", but geometries aligned 
and topoligized via the connections to GeoTrNet. Data exchange and mutual consistency strategy 
must be defined between RouLocNet and GeoTrNet for each actual implementation or deployment.

Remarks on operations and constraints: 
- Locations must be explicitly added and connected to their TrailNodes. 
  A Location may optionally have a polygon or a point geometry as a centroid 
  which suggests existing, new or moved TrailNodes to be linked to it.
- If a TrailSection is not covered by a SimpleTrailRoute in either direction, 
  a pseudo-route can be generated so that the network is always fully covered by SimpleRoutes
  and can be referenced by LogFM and TourPres.
- ...

### Location

Attributes:
- FullName (key): unique full name
- ShortName: ...
- PoiFeaturePictos: ...
- DefaultGeometry: ...
- DefaultAltitude: ...
- OsmId: OpenStreetMap identifier (optional)
 
### locAtTN

Connecting table with foreign keys of Location and TrailNode (many-to-many).
Location assignment can be recommended or generated, based on their geometries and the actual policy.

### POI

Attributes:
- OsmID (key): OpenStreetMap identifier
- Name: ...
- Type: ... (picto)

### poiAtTN

Connecting table with foreign keys of POI and TrailNode (many-to-many).
POI assignment can be recommended or generated, based on their geometries and the actual policy.

### SimpleRoute

### revOf

### containsTS

--------------------------

## TourPres

### locRel

### features (Location-POI)

### ComplexRoute

### srOf

### Route

### rtRel

### TripRoute

### RouteStage

### RouStageWpt

### stgOf

### tripOf

### MediaContent

### MapContent

### attachedTo

--------------------------

## LogFM

### LocationSign

### DestSign

### RouteDestSign

### SignTrkData

### RouteSign

### TrailSign

### TrailSignRule

### implies

### SuggSign

### InvSign

--------------------------

## PhyFM

### ImplementedSign

### pointsTo

### ImplicitSign

### Waymarking

### TrailMarker

### markOf

### Guidepost

### SignBoard

### InfoBoard

### rteInf

### displayedContent

### displayedSign

--------------------------

