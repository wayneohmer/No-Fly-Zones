//
//  GeoJSON.swift
//
//
//  Created by Wayne Ohmer on 5/17/15.
//  Copyright (c) 2015 Wayne Ohmer. All rights reserved.
//
import UIKit
import CoreLocation

//Not using enum here becaue these are used as dictionary keys.
struct GeoJSONkeys {
    static let feature = "Feature"
    static let features = "features"
    static let geometry = "geometry"
    static let geometries = "geometries"
    static let coordinates = "coordinates"
    static let properties = "properties"
    static let point = "Point"
    static let multiPoint = "MultiPoint"
    static let lineString = "LineString"
    static let multiLineString = "MultiLineString"
    static let polygon = "Polygon"
    static let multiPolygon = "MultiPolygon"
    static let geometryCollection = "GeometryCollection"
    static let featureCollection = "FeatureCollection"
    static let id = "id"
    static let bbox = "bbox"
    static let type = "type"
    static let crs = "crs"
    static let href = "href"
    static let name = "name"
    static let link = "link"
}

public class GeoJSON: NSObject {
    
    private(set) public var type:String?
    private(set) public var featureCollection:[GeoJSONFeature] = []
    private(set) public var feature:GeoJSONFeature?
    private(set) public var geometry:GeoJSONGeometry?
    private(set) public var crs:GeoJSONCrs?
    private(set) public var bbox:[CLLocation]?
    private(set) public var id:String?

    //Read-Only Computed Properties. Uses array filtering to return arrays of features of particular geometery types
    public var points:[GeoJSONFeature]{return self.featureCollection.filter({$0.geometry.type == GeoJSONkeys.point})}
    public var multipoints:[GeoJSONFeature]{return self.featureCollection.filter({$0.geometry.type == GeoJSONkeys.multiPoint})}
    public var lineStrings:[GeoJSONFeature]{return self.featureCollection.filter({$0.geometry.type == GeoJSONkeys.lineString})}
    public var multiLineStrings:[GeoJSONFeature]{return self.featureCollection.filter({$0.geometry.type == GeoJSONkeys.multiLineString})}
    public var polygons:[GeoJSONFeature]{return self.featureCollection.filter({$0.geometry.type == GeoJSONkeys.polygon})}
    public var multiPolygons:[GeoJSONFeature]{return self.featureCollection.filter({$0.geometry.type == GeoJSONkeys.multiPolygon})}
    public var geometryCollections:[GeoJSONFeature]{return self.featureCollection.filter({$0.geometry.type == GeoJSONkeys.geometryCollection})}

    //MARK: - Convenience inits
    convenience init(filename:String){
        //accept filename with or without extension.
        var resoursceName:String
        if filename.hasSuffix(".geojson"){
            resoursceName = filename.stringByDeletingPathExtension
        }else{
            resoursceName = filename
        }
        let path:String? = NSBundle.mainBundle().pathForResource(resoursceName, ofType: "geojson")
        if path == nil{
            println("Error! Could not find file \(resoursceName).geojson.")
            self.init()
        }else{
            self.init(path:path!)
        }
    }
    
    convenience init(path:String){
        if (!NSFileManager.defaultManager().fileExistsAtPath(path)){
            println("Error! Could not find file \(path) ")
            self.init()
        }else{
            self.init(data:NSData(contentsOfFile: path)!)
        }
    }
    
    convenience init(data:NSData){

        var error:NSError?

        let jsonDict:NSDictionary? = NSJSONSerialization.JSONObjectWithData(data,options: nil, error:&error) as? NSDictionary
        if error != nil{
            self.init()
            println("Error! Serialization Failure \(error!.localizedDescription)")
            return
        }
        self.init(dictionary:jsonDict!)
    }
    
    convenience init(dictionary:NSDictionary){

        self.init()
        if let bbox = dictionary[GeoJSONkeys.bbox] as? [CLLocationDegrees]{
            self.bbox = extractBbox(bbox)
        }
        if let thisId = dictionary[GeoJSONkeys.id] as? String{
            self.id = thisId
        }
        if let thisCrsDict = dictionary[GeoJSONkeys.crs] as? NSDictionary{
            self.crs = GeoJSONCrs(dictionary:thisCrsDict)
        }

        if let geoType = dictionary[GeoJSONkeys.type] as? String{
            switch geoType{
            case GeoJSONkeys.featureCollection:
                self.type = GeoJSONkeys.featureCollection
                if let featureDictArray = dictionary[GeoJSONkeys.features] as? [NSDictionary]{
                    for featureDict in featureDictArray{
                        self.featureCollection.append(extractFeatureFromDictionary(featureDict))
                    }
                }
            case GeoJSONkeys.feature:
                self.type = GeoJSONkeys.feature
                self.feature = extractFeatureFromDictionary(dictionary)
            case GeoJSONkeys.point, GeoJSONkeys.multiPoint, GeoJSONkeys.lineString, GeoJSONkeys.multiLineString, GeoJSONkeys.polygon, GeoJSONkeys.multiPolygon, GeoJSONkeys.geometryCollection:
                self.type = GeoJSONkeys.geometry
                self.geometry = extractGeometryFromDictionary(dictionary)
            default:
                println("Could not determine type from NSDictionary")
            }
        }
    }

    //MARK: - Utility funcs
    private func extractBbox(bbox:[CLLocationDegrees]) -> [CLLocation]{
        return [CLLocation(latitude: bbox[1], longitude: bbox[0]),CLLocation(latitude: bbox[3], longitude: bbox[2])]
    }
    
    private func extractFeatureFromDictionary(feature:NSDictionary) -> GeoJSONFeature{

        var returnFeature = GeoJSONFeature()

        if let properties = feature[GeoJSONkeys.properties] as? NSDictionary{
            // make properties dictionary
            returnFeature.properties = properties
            // handle simlpe cases of properties just being strings insteads of a big messy NSDictionary
            for (key,value) in properties{
                if key is String && value is String{
                    returnFeature.stringProperties[key as! String] = value as? String
                }
            }
        }
        if let bbox = feature[GeoJSONkeys.bbox] as? [CLLocationDegrees]{
            returnFeature.bbox = self.extractBbox(bbox)
        }
        if let thisId = feature[GeoJSONkeys.id] as? String{
            returnFeature.id = thisId
        }
        if let featureGeometry = feature[GeoJSONkeys.geometry] as? NSDictionary{
            returnFeature.geometry = self.extractGeometryFromDictionary(featureGeometry)
        }

        return returnFeature
    }
    
    private func extractGeometryFromDictionary(featureGeometryDict:NSDictionary) -> GeoJSONGeometry{
        
        func coordinateExtract(pointArray:[CLLocationDegrees]) -> CLLocation{
            return CLLocation(latitude: pointArray[1], longitude: pointArray[0])
        }

        func singleExtractArray(coordinateArray:NSArray) -> [CLLocation]{

            var returnArray = [CLLocation]()

            for pointArray in coordinateArray as! [[CLLocationDegrees]]{
                returnArray.append(coordinateExtract(pointArray))
            }
            return returnArray
        }

        func doubleExtractArray(coordinateArray:NSArray) -> [[CLLocation]]{

            var returnArray = [[CLLocation]]()

            for secondArray in coordinateArray as! [NSArray]{
                returnArray.append(singleExtractArray(secondArray))
            }
            return returnArray
        }

        func tripleExtractArray(coordinateArray:NSArray) -> [[[CLLocation]]]{

            var returnArray = [[[CLLocation]]]()

            for secondArray in coordinateArray as! [NSArray]{
                returnArray.append(doubleExtractArray(secondArray))
            }
            return returnArray

        }

        var returnGeometry = GeoJSONGeometry()

        if let thisType = featureGeometryDict[GeoJSONkeys.type] as? String{
            switch thisType {
            case GeoJSONkeys.point:
                returnGeometry =  GeoJSONGeometry(point:coordinateExtract(featureGeometryDict[GeoJSONkeys.coordinates] as! [CLLocationDegrees]))
            case GeoJSONkeys.multiPoint:
                returnGeometry =  GeoJSONGeometry(multiPoint:singleExtractArray(featureGeometryDict[GeoJSONkeys.coordinates] as! NSArray))
            case GeoJSONkeys.lineString:
                returnGeometry =  GeoJSONGeometry(lineString:singleExtractArray(featureGeometryDict[GeoJSONkeys.coordinates] as! NSArray))
            case GeoJSONkeys.multiLineString:
                returnGeometry =  GeoJSONGeometry(multiLineString:doubleExtractArray(featureGeometryDict[GeoJSONkeys.coordinates] as! NSArray))
            case GeoJSONkeys.polygon:
                returnGeometry =  GeoJSONGeometry(polygon:doubleExtractArray(featureGeometryDict[GeoJSONkeys.coordinates] as! NSArray))
            case GeoJSONkeys.multiPolygon:
                returnGeometry =  GeoJSONGeometry(multiPolygon:tripleExtractArray(featureGeometryDict[GeoJSONkeys.coordinates] as! NSArray))
            case GeoJSONkeys.geometryCollection:
                var thisGeometryCollection = [GeoJSONGeometry]()
                if let geometryDictArray = featureGeometryDict[GeoJSONkeys.geometries] as? [NSDictionary]{
                    for geometryDict in geometryDictArray{
                        //Recursion!
                        thisGeometryCollection.append(extractGeometryFromDictionary(geometryDict))
                    }
                    returnGeometry = GeoJSONGeometry(geometryCollection: thisGeometryCollection)
                }else{
                    println("geometryCollection did not contain array of geometries")
                }
            default:
                println("Feature geometry had invalid type \(thisType)")
            }
        }else{
            println("Feature geometry had no type")
        }

        return returnGeometry
    }

    //MARK: - url "init"
    class func GeoJSONWithUrl(url:String,completionHandler:(result: GeoJSON, error: String?) -> ()){

        var request = NSMutableURLRequest(URL: NSURL(string:url)!)
        var session = GeoJSONNSURLSession()

        session.httpGet(request) { (resultData, error) -> Void in
            if error == nil{
                completionHandler(result: GeoJSON(data:resultData!), error: error)
            }else{
                completionHandler(result: GeoJSON(), error: error)
            }
        }
    }

    public func buildFeatureDictionaryWithPropertyString(property:String) -> [String:[GeoJSON.GeoJSONFeature]!]{

        var returnDictionary:[String:[GeoJSONFeature]!] = [:]

        for feature in self.featureCollection{
            if let key = feature.stringProperties[property] {
                //This is wierd. returnDictionary[key] is optional even though I say it isn't above?
                if var array = returnDictionary[key]{
                    array.append(feature)
                    returnDictionary[key] = array
                }else{
                    returnDictionary[key] = [feature]
                }
            }
        }

        return returnDictionary
    }

    //MARK: - Local classes
    public class GeoJSONFeature: NSObject{
        
        private(set) public var geometry:GeoJSONGeometry = GeoJSONGeometry()
        private(set) public var properties = NSDictionary()
        // handle simple case of properties being strings instead of NSDictionary
        private(set) public var stringProperties = [String:String]()
        private(set) public var bbox:[CLLocation]?
        private(set) public var id:String?
        
    }

    public class GeoJSONCrs: NSObject{

        private(set) public var name:String = ""
        private(set) public var href:String = ""
        private(set) public var linkType:String = ""

        convenience init(dictionary:NSDictionary){
            self.init()
            if let properties = dictionary[GeoJSONkeys.properties] as? NSDictionary{
                if dictionary[GeoJSONkeys.type] as? String == GeoJSONkeys.name{
                    if properties[GeoJSONkeys.name] is String{
                        self.name = properties[GeoJSONkeys.name] as! String
                    }
                }
                if dictionary[GeoJSONkeys.type] as? String == GeoJSONkeys.link{
                    if properties[GeoJSONkeys.href] is String{
                        self.href = properties[GeoJSONkeys.href] as! String
                    }
                    if properties[GeoJSONkeys.type] is String{
                        self.linkType = properties[GeoJSONkeys.type] as! String
                    }
                }
            }
        }
    }
    
    public class GeoJSONGeometry: NSObject{
        
        private(set) public var type:String = ""
        private(set) public var point:CLLocation = CLLocation()
        private(set) public var multiPoint:[CLLocation] = []
        private(set) public var lineString:[CLLocation] = []
        private(set) public var multiLineString:[[CLLocation]] = [[]]
        private(set) public var polygon:[[CLLocation]] = [[]]
        private(set) public var multiPolygon:[[[CLLocation]]] = [[[]]]
        private(set) public var geometryCollection:[GeoJSONGeometry] = []
        lazy private var bounds:[CLLocationCoordinate2D] = self.findBounds()

        //Read only Computed Properties
        public var boundsSouthWest:CLLocationCoordinate2D{return self.bounds[0]}
        public var boundsNorthEast:CLLocationCoordinate2D{return self.bounds[1]}
        public var center:CLLocationCoordinate2D{
            let centerLatittue = self.boundsNorthEast.latitude - ((self.boundsNorthEast.latitude - self.boundsSouthWest.latitude)/2)
            let centerLongitude = self.boundsNorthEast.longitude - ((self.boundsNorthEast.longitude - self.boundsSouthWest.longitude)/2)
            return CLLocationCoordinate2D(latitude: centerLatittue, longitude:centerLongitude)
        }
        convenience init(point:CLLocation){
            self.init()
            self.type = GeoJSONkeys.point
            self.point = point
        }
        
        convenience init(multiPoint:[CLLocation]){
            self.init()
            self.type = GeoJSONkeys.multiPoint
            self.multiPoint = multiPoint
        }
        
        convenience init(lineString:[CLLocation]){
            self.init()
            self.type = GeoJSONkeys.lineString
            self.lineString = lineString
        }
        
        convenience init(polygon:[[CLLocation]]){
            self.init()
            self.type = GeoJSONkeys.polygon
            self.polygon = polygon
        }
        
        convenience init(multiPolygon:[[[CLLocation]]]){
            self.init()
            self.type = GeoJSONkeys.multiPolygon
            self.multiPolygon = multiPolygon
        }
        
        convenience init(multiLineString:[[CLLocation]]){
            self.init()
            self.type = GeoJSONkeys.multiLineString
            self.multiLineString = multiLineString
        }
        
        convenience init(geometryCollection:[GeoJSONGeometry]){
            self.init()
            self.type = GeoJSONkeys.geometryCollection
            self.geometryCollection = geometryCollection
        }
        // return true if point is inside a polygon or inside any of one of a mulitpolygon. works recursively with a geometry collection.
        public func surroundsPoint(testPoint:CLLocation) -> Bool{

            func evaluatePolygon(polygon:[[CLLocation]]) -> Bool{
                // adapted from http://www.ecse.rpi.edu/Homepages/wrf/Research/Short_Notes/pnpoly.html
                func evaluateArray(locationArray:[CLLocation]) -> Bool{
                    let testPointLongitude = testPoint.coordinate.longitude
                    let testPointLatitude = testPoint.coordinate.latitude
                    var lastPolygonPoint = locationArray[locationArray.count-1]
                    var arrayAnswer:Bool = false
                    //Basic idea, run a semi-infinite ray horizontally (increasing Latitude, fixed Longitude ) out from the test point, and count how many edges it crosses. At each crossing, the ray switches between inside and outside.
                    for thisPolygonPoint in locationArray{
                        let thisLongitude = thisPolygonPoint.coordinate.longitude
                        let lastLongitude = lastPolygonPoint.coordinate.longitude
                        let thisLatitude  = thisPolygonPoint.coordinate.latitude
                        let lastLatitude = lastPolygonPoint.coordinate.latitude
                        if (((thisLongitude > testPointLongitude) != (lastLongitude > testPointLongitude)) && (testPointLatitude < (lastLatitude - thisLatitude)*(testPointLongitude - thisLongitude) / (lastLongitude - thisLongitude) + thisLatitude)){
                            arrayAnswer = !arrayAnswer
                        }
                        lastPolygonPoint = thisPolygonPoint
                    }
                    return arrayAnswer
                }
                var polygonAnswer:Bool = false
                var outerAnswer:Bool = false
                var innerAnswer:Bool = false
                //polygon[0] is the "outer" polygon
                if polygon[0].count > 0{
                    outerAnswer = evaluateArray(polygon[0])
                }
                // see if there is an "inner" polygon(polygon[1]) and see if the point is inside.
                if polygon.count > 1 && polygon[1].count > 0{
                    innerAnswer = evaluateArray(polygon[1])
                }
                //make sure clicking in Lesotho will not return true for South Africa.
                if outerAnswer && !innerAnswer{
                    polygonAnswer = true
                }
                return polygonAnswer
            }

            var answer:Bool = false
            switch self.type{
            case GeoJSONkeys.polygon:
                answer = evaluatePolygon(self.polygon)
            case GeoJSONkeys.multiPolygon:
                for polygon in self.multiPolygon{
                    if evaluatePolygon(polygon){
                        answer = true
                        break
                    }
                }
            case GeoJSONkeys.geometryCollection:
                for geometry in self.geometryCollection{
                    if geometry.surroundsPoint(point){
                        answer = true
                        break
                    }
                }
            default:
                answer = false
            }
            return answer
        }
        //returns the bounding box of a feature geometry. Private because boundsSouthWest and boundsNorthEast return the value is a nicer form.
        private func findBounds() -> [CLLocationCoordinate2D]{

            //initialize with oposite extreme
            var maxLatitute:CLLocationDegrees = -90
            var maxLongitude:CLLocationDegrees = -180
            var minLatitute:CLLocationDegrees = 90.0
            var minLongitude:CLLocationDegrees = 180.0

            func processLocationArray(polygon:[CLLocation]){
                for point in polygon{
                    if point.coordinate.longitude > maxLongitude{
                        maxLongitude = point.coordinate.longitude
                    }
                    if point.coordinate.latitude > maxLatitute{
                        maxLatitute = point.coordinate.latitude
                    }
                    if point.coordinate.longitude < minLongitude{
                        minLongitude = point.coordinate.longitude
                    }
                    if point.coordinate.latitude < minLatitute{
                        minLatitute = point.coordinate.latitude
                    }
                }
            }

            switch self.type{
            case GeoJSONkeys.multiPoint:
                processLocationArray(self.multiPoint)
            case GeoJSONkeys.lineString:
                processLocationArray(self.lineString)
            case GeoJSONkeys.multiLineString:
                for lineString in self.multiLineString{
                    processLocationArray(lineString)
                }
            case GeoJSONkeys.polygon:
                //index [0] because inner polygon will not affect bounds
                processLocationArray(self.polygon[0])
            case GeoJSONkeys.multiPolygon:
                for polygon in self.multiPolygon{
                    //index [0] because inner polygon will not affect bounds
                    processLocationArray(polygon[0])
                }
            default:
                return [CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0),CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)]
            }

            return [CLLocationCoordinate2D(latitude: minLatitute,longitude: minLongitude),CLLocationCoordinate2D(latitude: maxLatitute,longitude: maxLongitude)]
        }
    }

    //MARK: - NSURLsession Class.
    class GeoJSONNSURLSession: NSObject,NSURLSessionDelegate,NSURLSessionTaskDelegate  {
        
        func httpGet(request: NSMutableURLRequest!, completionHandler: (NSData?,  String?) -> Void) {
            var session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(),delegate:self,delegateQueue:nil)
            var task = session.dataTaskWithRequest(request){
                (data: NSData!, response: NSURLResponse!, error: NSError!) -> Void in
                if error != nil {
                    completionHandler(nil, error.localizedDescription)
                } else {
                    completionHandler(data,nil)
                }
            }
            task.resume()
        }

        //handle https
        func URLSession(session: NSURLSession,didReceiveChallenge challenge: NSURLAuthenticationChallenge,completionHandler:(NSURLSessionAuthChallengeDisposition,NSURLCredential!) -> Void) {
            completionHandler( NSURLSessionAuthChallengeDisposition.UseCredential, NSURLCredential(forTrust:challenge.protectionSpace.serverTrust))
        }

        //handle http
        func URLSession(session: NSURLSession,task: NSURLSessionTask,willPerformHTTPRedirection response: NSHTTPURLResponse,newRequest request: NSURLRequest,completionHandler: (NSURLRequest!) -> Void) {
            var newRequest : NSURLRequest? = request
            completionHandler(newRequest)
        }
    }
    
}
