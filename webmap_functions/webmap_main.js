
var L = require('leaflet');
var $ = require('jquery');

var map = L.map('map').setView([47.79, 18.77], 13);

// Additional providers are available at: https://leaflet-extras.github.io/leaflet-providers/preview/
L.tileLayer('https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png', {
    //attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a> &copy; <a href="https://carto.com/attributions">CARTO</a>',
    maxZoom: 16,
    opacity: "60%"
}).addTo(map);

L.tileLayer('https://tile.waymarkedtrails.org/hiking/{z}/{x}/{y}.png', {
    maxZoom: 16,
    opacity: "50%"
}).addTo(map);

//var signpostLayer = L.geoJSON().addTo(map);
//signpostLayer.addData(geojsonFeature);

$.ajax({
    type: "GET",
    url: "./signposts",
    dataType: "json",
    success: function(response) {
        console.log(response);
        L.geoJson(response[0].jsonb_build_object, {
            onEachFeature: onEachFeature
        }).addTo(map);
    },
    error: function(response) {
        console.log(response);
    }
})//.error(function(response) { console.log(response) });

function onEachFeature(feature, layer) {
    layer.bindPopup("count: " + feature.properties.count + "<br>ids: " + feature.properties.ids + "<br>signs:<br>" + feature.properties.txts);
}

map.on('click', function(e) {
    var lat = e.latlng.lat;
    var lng = e.latlng.lng;
    document.getElementById('coordy').value = lat + " " + lng;
});
