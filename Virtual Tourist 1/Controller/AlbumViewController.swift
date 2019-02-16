//
//  AlbumViewController.swift
//  Virtual Tourist 1
//
//  Created by hind on 2/11/19.
//  Copyright © 2019 hind. All rights reserved.
//
import Foundation
import UIKit
import MapKit
import CoreData

class AlbumViewController: UIViewController,UICollectionViewDelegate,MKMapViewDelegate,UICollectionViewDataSource, NSFetchedResultsControllerDelegate {
   
    
    // MARK: Properties
    var currentPin: Pin!
    //var newPin = true
    var dataController:DataController!
    var fetchedResultsController:NSFetchedResultsController<Photo>!
    let flickr = Flickrclient.shared()
    var selectedPhototIndex : [IndexPath] = []
    var downloadingState = false
    var selectingState = false
    var StopDownloading = false
    
    var insertedIndexPaths: [IndexPath]!
    var deletedIndexPaths: [IndexPath]!
    var updatedIndexPaths: [IndexPath]!
    
    
    @IBOutlet weak var NewCollectionBtn: UIButton!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    
     //MARK: UI Configuration Enum
    enum UIState { case Downloading , Normal , Selecting }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        mapView.isUserInteractionEnabled = true
        setupFetchedResultsController()
        setTheMap()
        setCollectionView()
        self.view.backgroundColor = .blue
        self.navigationItem.title = title
        self.navigationController?.navigationBar.barTintColor = .white
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: makeBackButton())
    }
    
  
    override func viewDidDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchedResultsController = nil
        StopDownloading = true
        flickr.cancel()
    }
    func makeBackButton() -> UIButton {
        let backButtonImage = UIImage(named:"backButton")?.withRenderingMode(.alwaysTemplate)
        let backButton = UIButton(type: .custom)
        backButton.setImage(backButtonImage, for: .normal)
        backButton.tintColor = .blue
        backButton.setTitle("  Back", for: .normal)
        backButton.setTitleColor(.blue, for: .normal)
        backButton.addTarget(self, action: #selector(self.backButtonPressed), for: .touchUpInside)
        return backButton
    }
    
    @objc func backButtonPressed() {
      
        self.navigationController?.popViewController(animated: true)
    }
    fileprivate func setTheMap() {
        // place pin on Map
        let initialLocation = CLLocation(latitude:(currentPin?.latitude)!, longitude: (currentPin?.longitude)!)
        let regionRadius: CLLocationDistance = 1000
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(initialLocation.coordinate,
                                                                  regionRadius, regionRadius)
        mapView.setRegion(coordinateRegion, animated: true)
        let annotation = MKPointAnnotation()
        annotation.coordinate = CLLocationCoordinate2D(latitude: (currentPin?.latitude)!, longitude: (currentPin?.longitude)!)
        mapView.addAnnotation(annotation)
    }
    fileprivate func setCollectionView() {
        // ADD Tap Gesture To collection view
        let longPressGesture = UITapGestureRecognizer(target: self, action: #selector(handleLongPress(gesture:)))
        collectionView!.addGestureRecognizer(longPressGesture)
        // set up collection view
        collectionView!.delegate = self
        collectionView!.dataSource = self
        // set flow layout properties.
        let space:CGFloat = 3.0
        let dimension = (view.frame.size.width - (2 * space)) / 3.0
        // the space between items within a row or column
        flowLayout.minimumInteritemSpacing = space
        //the space between rows or columns
        flowLayout.minimumLineSpacing = space
        //cell size
        flowLayout.itemSize = CGSize(width: dimension, height: dimension)
    }
    //_________________Fetch Photo_______________________//
    
    fileprivate func setupFetchedResultsController() {
        let fetchRequest:NSFetchRequest<Photo> = Photo.fetchRequest()
        let predicate = NSPredicate(format: "location == %@", currentPin!)
        fetchRequest.predicate = predicate
        let sortDescriptor = NSSortDescriptor(key: "title", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
        do {
            try fetchedResultsController.performFetch()
        } catch {
            fatalError("The fetch could not be performed: \(error.localizedDescription)")
        }
        if (fetchedResultsController.fetchedObjects?.isEmpty)!{
            
            downloading (long: (currentPin?.longitude)! , lati: (currentPin?.latitude)!)
        }
    }
    
    // MARK: Search Actions
    func downloading (long : Double , lati : Double) {
        
        setUIForState(.Downloading)
        flickr.makeRequest(latitude: lati , longitude: long) { (totalPages, error) in
            if error != nil
            {
                DispatchQueue.main.async {
                    self.setUIForState(.Normal)
                    self.showAlert(withTitle: "Error", withMessage: "No photo returned. Try again.") }
            }else {
                // pick a random page!
                let pageLimit = min(totalPages, 40)
                let randomPage = Int(arc4random_uniform(UInt32(pageLimit))) + 1
                self.flickr.displayImageFromFlickrBySearch(withPageNumber: randomPage){ (imageUrlString, error) in
                    if error != nil
                    {
                        DispatchQueue.main.async {
                            self.setUIForState(.Normal)
                            self.showAlert(withTitle: "Error", withMessage: "No photo returned. Try again.") }
                    }else{
                        if !imageUrlString.isEmpty
                        {
                            for index in 0...imageUrlString.count-1 {
                                if !(self.StopDownloading){
                                    // if an image exists at the url, set the image and title
                                    let imageURL = URL(string: imageUrlString[index])
                                    if let imageData = try? Data(contentsOf: imageURL!) {
                                        DispatchQueue.main.async {
                                            let photo = Photo(context: self.dataController.viewContext)
                                            photo.image = imageData
                                            photo.location = self.currentPin
                                            try? self.dataController.viewContext.save()
                                        }} }}
                            
                        }
                      
                        // Dawnload Completed
                        DispatchQueue.main.async {
                            self.setUIForState(.Normal)
                        } }}}}}
    
    
    // MARK: UICollectionViewDataSource
    
 func numberOfSections(in collectionView: UICollectionView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        if let count = self.fetchedResultsController.sections?.count {
            return count
        }
        return 1
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of items
        if let count = fetchedResultsController.sections?[section].numberOfObjects
        {return count}
        return 0
    }
    
   func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCollectionViewCell",for: indexPath) as! CustomCell
        cell.ActivityIndicator.startAnimating()
        let photo = fetchedResultsController.object(at: indexPath)
        let img = UIImage(data: photo.image!)
        cell.imageView?.image = img
        if (selectedPhototIndex.contains(indexPath)){
            cell.imageView.alpha = 0.3
        }
        else {
            cell.imageView.alpha = 1
        }
        cell.ActivityIndicator.stopAnimating()
        cell.ActivityIndicator.isHidden = true
        return cell
        
    }
    // MARK: UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let deletedPhoto = fetchedResultsController.object(at: indexPath)
        dataController.viewContext.delete(deletedPhoto)
        try! self.dataController.viewContext.save()
    }
    
    @objc func handleLongPress(gesture: UITapGestureRecognizer) {
        
        let p = gesture.location(in: self.collectionView)
        let indexPath = self.collectionView!.indexPathForItem(at: p)
        if let index = indexPath {
            let cell = self.collectionView!.cellForItem(at: index) as? CustomCell
            if (selectedPhototIndex.contains(index))
            {
                let i = selectedPhototIndex.index(of: index)
                selectedPhototIndex.remove(at: i!)
                cell?.imageView.alpha = 1
            }
            else {
                selectedPhototIndex.append(index)
                cell?.imageView.alpha = 0.3
            }
            if (selectedPhototIndex.isEmpty){
                setUIForState(.Normal)
            }
            else {
                setUIForState(.Selecting)
            }  }  }

    func deleteSelectedPhoto(){
        selectedPhototIndex.sort(){$0>$1}
        for index in selectedPhototIndex
        {
            let photo = fetchedResultsController.object(at: index)
            dataController.viewContext.delete(photo)
            
        }
        selectedPhototIndex.removeAll()
        try?  dataController.viewContext.save()
        setUIForState(.Normal)
    }
    
    func UpdateColletion(){
        for oldPhoto in fetchedResultsController.fetchedObjects!
        {dataController.viewContext.delete(oldPhoto)}
        try?  dataController.viewContext.save()
        downloading(long: (currentPin?.longitude)!, lati: (currentPin?.latitude)!)
        
    }
    
    
    @IBAction func CreateNewCollection(_ sender: Any) {
        if selectingState {
            deleteSelectedPhoto()
        }
        else {
            UpdateColletion()
        }
    }
    
    
    func setUIForState(_ state: UIState) {
        switch state {
        case .Downloading:
            selectingState = false
            downloadingState = true
            NewCollectionBtn.isHidden = true
        case .Normal :
            selectingState = false
            downloadingState = false
            NewCollectionBtn.isUserInteractionEnabled = true
            NewCollectionBtn.isHidden = false
            NewCollectionBtn.setTitle("New Collection", for: .normal)
        case .Selecting :
            selectingState = true
            NewCollectionBtn.setTitle("Remove Selected Photo", for: .normal)
        }
    }
    
    func showAlert(withTitle title: String, withMessage message:String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default , handler: nil))
        DispatchQueue.main.async(execute: {
            self.present(alert, animated: true)
        })
    }

   
}
extension AlbumViewController {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        insertedIndexPaths = [IndexPath]()
        deletedIndexPaths = [IndexPath]()
        updatedIndexPaths = [IndexPath]()
    }
    
    func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChange anObject: Any,
        at indexPath: IndexPath?,
        for type: NSFetchedResultsChangeType,
        newIndexPath: IndexPath?) {
        
        switch (type) {
        case .insert:
            insertedIndexPaths.append(newIndexPath!)
            break
        case .delete:
            deletedIndexPaths.append(indexPath!)
            break
        case .update:
            updatedIndexPaths.append(indexPath!)
            break
        case .move:
            print("Move an item. We don't expect to see this in this app.")
            break
        }
        
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        
        collectionView.performBatchUpdates({() -> Void in
            
            for indexPath in self.insertedIndexPaths {
                self.collectionView.insertItems(at: [indexPath])
            }
            
            for indexPath in self.deletedIndexPaths {
                self.collectionView.deleteItems(at: [indexPath])
            }
            
            for indexPath in self.updatedIndexPaths {
                self.collectionView.reloadItems(at: [indexPath])
            }
            
        }, completion: nil)
    }
    
}


