//
//  ViewController.swift
//  Virtual Tourist 1
//
//  Created by hind on 2/10/19.
//  Copyright © 2019 hind. All rights reserved.
//

import UIKit
import MapKit
import CoreData
import CoreLocation
class TravelLocationsMapVC: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate,UIGestureRecognizerDelegate {
   
    
    //------------------------------------------------------------------------------
    // MARK: Outlets
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var activityIndicatorMap: UIActivityIndicatorView!
    
    //------------------------------------------------------------------------------
    // MARK: Vars/Lets
    var pin : Pin!
    var pins : [Pin] = []
    var dataController: DataController!
    let fetchRequest: NSFetchRequest<Pin> = Pin.fetchRequest()
    var fetchedResultsController:NSFetchedResultsController<Pin>!
    var EditBtn : UIBarButtonItem!
    var DoneBtn : UIBarButtonItem!
    var deleteLabel : UILabel!
    var deleteMode  = false
   
    
     //------------------------------------------------------------------------------
    //MARK: UI Configuration Enum
    enum UIState { case delete, Normal }
   
    //------------------------------------------------------------------------------
    // MARK: Life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        activityIndicatorMap.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        activityIndicatorMap.startAnimating()
        setupLongPressGestureRecognizer()
        //setUI
        EditBtn = UIBarButtonItem(title: "Edit", style: .done, target: self, action: #selector(deletePin))
        DoneBtn = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(deletePin))
        self.navigationItem.rightBarButtonItem = EditBtn
        deleteLabel = UILabel(frame: CGRect(x: 0, y: self.view.frame.size.height , width: self.view.frame.size.width, height: 50))
        deleteLabel.text = "Tap pin to delete"
        deleteLabel.textColor = UIColor.white
        deleteLabel.backgroundColor = UIColor.red
        deleteLabel.textAlignment = NSTextAlignment.center
        setUIForState(.Normal)
    
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Display the pin locations on the map
        displayPinLocations()
        self.activityIndicatorMap.stopAnimating()
    }
   
    //------------------------------------------------------------------------------
    // MARK: Action
    @objc func deletePin(_ sender: Any) {
        if (deleteMode)
        {
            setUIForState(.Normal)
            deleteMode = false
            if pins.isEmpty {
                EditBtn.isEnabled = false
            }}
        else {
            setUIForState(.delete)
            deleteMode = true
        }
    }
    
    
    //------------------------------------------------------------------------------
    // MARK: Handling Long Press
    // MARK: After The Long Press Take Location Coordinate and Make New One
    
    @objc func addAnnotationOnLongPress(gesture: UILongPressGestureRecognizer) {
        if gesture.state != UIGestureRecognizerState.ended {
            return
        }
        // Add a pin at site of long press to the map
        let touchPoint = gesture.location(in: mapView)
        let newCoordinates = mapView.convert(touchPoint, toCoordinateFrom: mapView)
        let annotation = MKPointAnnotation()
        annotation.coordinate = newCoordinates
        mapView.addAnnotation(annotation)
        addPin(long: newCoordinates.longitude, lat: newCoordinates.latitude)
    
        }
    
    
    // Adds a new Pin to the end of the `Pin` array
    func addPin(long: Double , lat : Double) {
        let pin = Pin(context: dataController.viewContext)
        pin.longitude = long
        pin.latitude = lat
        try? dataController.viewContext.save()
        pins.append(pin)
        displayPinLocations()
    }
    
    
    // MARK:  Core Data setup - Fetched Results Controller
    fileprivate func setupFetchedResultsController() {
        let fetchRequest:NSFetchRequest<Pin> = Pin.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true),NSSortDescriptor(key: "latitude", ascending: false)]
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        do {
            try fetchedResultsController.performFetch()
        } catch {
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Error", message: "", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title:NSLocalizedString("Ok", comment: "Default Action"), style: .default))
                alert.message = "The fetch could not be performed: \(error.localizedDescription)"
                self.present(alert, animated: true, completion: nil)
            }
        }}
    
    // MARK:  - MKMapView
    fileprivate func displayPinLocations() {
        setupFetchedResultsController()
        var annotations = [MKPointAnnotation]()
        for pin in (fetchedResultsController.fetchedObjects)! {
            let lat = CLLocationDegrees(pin.latitude)
            let lon = CLLocationDegrees(pin.longitude)
            
            // The lat and lon are used to create a CLLocationCoordinates2D instance.
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            
            // Create the annotation and set its coordiate, title, and subtitle properties
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            
            // Finally we place the annotation in an array of annotations.
            annotations.append(annotation)
            
        }
        // When the array is complete, we add the annotations to the map.
        self.mapView.addAnnotations(annotations)
        
    }

    // -------------------------------------------------------------------------
    // MARK: - UI Setting
    
    func setUIForState(_ state: UIState) {
        switch state {
        case .delete:
            view.frame.origin.y -= deleteLabel.frame.height
            self.view.addSubview(deleteLabel)
            deleteLabel.isHidden = false
            self.navigationItem.rightBarButtonItem  = DoneBtn
        case .Normal:
            deleteLabel.removeFromSuperview()
            deleteLabel.isHidden = true
            view.frame.origin.y = 0
            self.navigationItem.rightBarButtonItem  = EditBtn
        }}
    
    // -------------------------------------------------------------------------
    // MARK: - MKMapViewDelegate
    
    func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
        self.activityIndicatorMap.stopAnimating()
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        let reuseId = "pin"
        var pinV = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
        
        if pinV == nil {
            pinV = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinV!.pinTintColor = UIColor.red
        }
        else {
            pinV!.annotation = annotation
        }
        return pinV
    }
   // Go through pin database to find selected pin, then pass to next controller

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
    
        // Get coordinates for selected pin
       // let annotation = view.annotation as! MKPointAnnotation
        let selectedAnnotation = view.annotation
        let selectedAnnotationLat = selectedAnnotation?.coordinate.latitude
        let selectedAnnotationLong = selectedAnnotation?.coordinate.longitude
        var selectedPin: Pin
        if let result = fetchedResultsController.fetchedObjects {
            for pin in result {
                if pin.latitude == selectedAnnotationLat && pin.longitude == selectedAnnotationLong {
                              selectedPin = pin
                            if  deleteMode == false {
                        
                                 let vc = self.storyboard?.instantiateViewController(withIdentifier:"ToPhotoAlbum") as! AlbumViewController
                                    vc.dataController = dataController
                                    vc.currentPin = selectedPin
                                    vc.newPin = false
                                    self.navigationController?.pushViewController(vc, animated: true)
                               // }
                               } else {
                                    // Delete pin from map and database
                                   DispatchQueue.main.async {
                                        self.mapView.removeAnnotations(mapView.annotations)
                                        self.dataController.viewContext.delete(selectedPin)
                                        try? self.dataController.viewContext.save()
                                       self.displayPinLocations()
                                  }
                        }
                }}}}
       
    }
extension TravelLocationsMapVC {

    
    fileprivate func setupLongPressGestureRecognizer() {
    
    // Set variables for detecting long press to drop pin
    let longPressRecogniser = UILongPressGestureRecognizer(target: self, action: #selector(addAnnotationOnLongPress(gesture:)))
    longPressRecogniser.minimumPressDuration = 0.5
    longPressRecogniser.delaysTouchesBegan = true
    longPressRecogniser.delegate = self
    mapView.delegate = self
    mapView.isUserInteractionEnabled = true
    mapView.addGestureRecognizer(longPressRecogniser)
    
    }

    
}

