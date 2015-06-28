//
//  ViewController.swift
//  No Fly Zones
//
//  Created by Wayne Ohmer on 6/27/15.
//  Copyright (c) 2015 Wayne Ohmer. All rights reserved.
//

import UIKit

class MapViewController: UIViewController {

    @IBOutlet var mapView: RMMapView!
    let airportSourceUrl = "https://raw.githubusercontent.com/mapbox/drone-feedback/master/sources/geojson/5_mile_airport.geojson"
    let militarySourceUrl = "https://raw.githubusercontent.com/mapbox/drone-feedback/master/sources/geojson/us_military.geojson"
    let parksSourceUrl = "https://raw.githubusercontent.com/mapbox/drone-feedback/master/sources/geojson/us_national_park.geojson"

    var militaryGeoJSON:GeoJSON?
    var airportGeoJSON:GeoJSON?
    var parksGeoJSON:GeoJSON?
    var USAGoeJSON:GeoJSON?
    //this is quick and cheesey. Better done with enum
    var networkDone:[Bool] = [false,false,false]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        RMConfiguration.sharedInstance().accessToken = "pk.eyJ1Ijoid2F5bmVvaG1lciIsImEiOiJqcHpkUFlVIn0.Ckoh0O9yUJ1E8WoFC8nhhg"
        self.mapView.tileSource = RMMapboxSource(mapID: "mapbox.light")
        self.mapView.autoresizingMask = .FlexibleHeight | .FlexibleWidth
        self.mapView.delegate = self
        dispatch_async(dispatch_get_main_queue()){
            self.mapView.centerCoordinate = CLLocationCoordinate2D(latitude: 41.244, longitude: -100.81)
            self.mapView.zoom = 5
        }
        //used border of USA only draw annotations inside the border
        self.USAGoeJSON = GeoJSON(filename: "USA")
        
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        // a lot of duplicated code here. More time will produce a clever local func solution
        GeoJSON.GeoJSONWithUrl(self.militarySourceUrl) {(completionGeonJSON,error) -> Void in
            if (error == nil){
                self.militaryGeoJSON = completionGeonJSON
                dispatch_async(dispatch_get_main_queue()){
                    self.makeAnnotations(self.militaryGeoJSON!,title:"Military")
                }
            }else{
                println(error)
            }
            self.networkDone[0] = true
            if self.networkDone[0] && self.networkDone[1] && self.networkDone[2]{
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            }
            println("Military Done")
        }
        
        GeoJSON.GeoJSONWithUrl(self.airportSourceUrl) {(completionGeonJSON,error) -> Void in
            if (error == nil){
                self.airportGeoJSON = completionGeonJSON
                dispatch_async(dispatch_get_main_queue()){
                    self.makeAnnotations(self.airportGeoJSON!,title:"Airport")
                }
            }else{
                println(error)
            }
            self.networkDone[1] = true
            if self.networkDone[0] && self.networkDone[1] && self.networkDone[2]{
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            }
            println("Airports Done")
        }
        
        GeoJSON.GeoJSONWithUrl(self.parksSourceUrl) {(completionGeonJSON,error) -> Void in
            if (error == nil){
                self.parksGeoJSON = completionGeonJSON
                //no annotations for parks. mapbox can't handle them
            }else{
                println(error)
            }
            self.networkDone[2] = true
            if self.networkDone[0] && self.networkDone[1] && self.networkDone[2]{
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            }
            println("Parks Done")
        }
        
    }
    
    func makeAnnotations(thisGeonJSON:GeoJSON,title:String){
        
        func addAnnotationWithPolygon(polygon:[[CLLocation]]){
            for line in polygon{
                var zoneAnnotation = RMAnnotation(mapView: self.mapView, coordinate: line[0].coordinate, andTitle:title)
                //userInfo is used to store "shape" array to be used in layerForAnnotation delegate func
                zoneAnnotation.userInfo = line
                self.mapView!.addAnnotation(zoneAnnotation)
            }
        }
        
        for feature in thisGeonJSON.featureCollection{
            let centerLocation = CLLocation(latitude:feature.geometry.center.latitude,longitude:feature.geometry.center.longitude)
            if self.USAGoeJSON!.feature!.geometry.surroundsPoint(centerLocation){
                if feature.geometry.type == GeoJSONkeys.polygon{
                    addAnnotationWithPolygon(feature.geometry.polygon)
                }else if feature.geometry.type == GeoJSONkeys.multiPolygon{
                    for polygon in feature.geometry.multiPolygon{
                        addAnnotationWithPolygon(polygon)
                    }
                }
            }
        }
   }
}

extension MapViewController: RMMapViewDelegate {
    
    func singleTapOnMap(map: RMMapView!, at point: CGPoint) {
        
        func presentInfoTaleView(feature:GeoJSON.GeoJSONFeature){
            let storyBoard = UIStoryboard(name: "Main", bundle: nil)
            var infoNavController = storyBoard.instantiateViewControllerWithIdentifier("InfoNavController") as! UINavigationController
            var infoTableViewController = infoNavController.visibleViewController as! InfoTableViewController
            // quick and dirty header cell.
            if let parkName = feature.stringProperties["PARKNAME"] {
                infoTableViewController.infoArray.append("Park : \(parkName)")
            }
            if let baseName = feature.stringProperties["INSTALLATI"] {
                infoTableViewController.infoArray.append("Military Base : \(baseName)")
            }
            if let airportName = feature.stringProperties["name"] {
                infoTableViewController.infoArray.append("Airport : \(airportName)")
            }
            //put touch location in info cell.
            infoTableViewController.infoArray.append("Touch: \(self.mapView.pixelToCoordinate(point).latitude) : \(self.mapView.pixelToCoordinate(point).longitude)")
            for (key,value) in feature.stringProperties{
                infoTableViewController.infoArray.append("\(key) : \(value)")
            }
            infoNavController.modalTransitionStyle = UIModalTransitionStyle.CoverVertical
            self.presentViewController(infoNavController, animated: true, completion: nil)
        }
        
        let tapLocation = CLLocation(latitude:self.mapView.pixelToCoordinate(point).latitude,longitude:(self.mapView.pixelToCoordinate(point).longitude))
        if militaryGeoJSON != nil {
            for  feature in militaryGeoJSON!.featureCollection{
                if (feature.geometry.surroundsPoint(tapLocation)){
                    presentInfoTaleView(feature)
                }
            }
        }
        
        if airportGeoJSON != nil{
            for  feature in airportGeoJSON!.featureCollection{
                if (feature.geometry.surroundsPoint(tapLocation)){
                    presentInfoTaleView(feature)
                }
            }
        }
        
        if parksGeoJSON != nil{
            for  feature in parksGeoJSON!.featureCollection{
                if (feature.geometry.surroundsPoint(tapLocation)){
                    presentInfoTaleView(feature)
                }
            }
        }
    }
    
    func mapView(mapView: RMMapView!, layerForAnnotation annotation:RMAnnotation) -> RMMapLayer {
        
        var shape = RMShape(view: self.mapView)
        
        if annotation.title == "Military"{
            shape.lineColor = UIColor.redColor()
        }else{ //this really means airport
            shape.lineColor = UIColor.blueColor()
        }
        shape.lineWidth = 2.0
        for location in annotation.userInfo as! [CLLocation]{
            shape.addLineToCoordinate(location.coordinate)
        }
        return shape
    }
}
