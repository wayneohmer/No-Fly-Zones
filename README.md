# No-Fly-Zones

##Proof of concept app to display drone no-fly zones inside the United States.

Touch the map inside a no-fly zone and it will give you basic info about that zone. The borders of military base(red) and airport(blue) zones and displayed.  Borders of national parks are not shown (see reason below) but touching inside one will still show you information about the park.  

No-fly zone data comes from here:

https://github.com/mapbox/drone-feedback/tree/master/sources/geojson

National park borders are not shown because the data is very complex and it overwhelmed Mapbox's annotation feature. This could be fixed with some optimizations.  

This app was put together quickly to demonstrate what is possible;  as such, it is not optimized.  Among other things it uses too much memory, and performs best in the simulator where it has the resources of a real computer behind it.
