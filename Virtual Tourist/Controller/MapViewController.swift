//
//  MapViewController.swift
//  Virtual Tourist
//

import Foundation
import UIKit
import MapKit
import CoreLocation
import CoreData

class MapViewController: UIViewController {
    
    // MARK: Properties
    
    @IBOutlet weak var mapView: MKMapView!
    
    var currentAnnotation: MKPointAnnotation?
    var annotations: [MKPointAnnotation] = []
    
    let stack = (UIApplication.shared.delegate as! AppDelegate).stack
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Pin")
    
    var fetchedResultsController : NSFetchedResultsController<NSFetchRequestResult>? {
        didSet {
            executeSearch()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create a fetchrequest
        fetchRequest.sortDescriptors = []
        
        // Create the FetchedResultsController
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: stack.context, sectionNameKeyPath: nil, cacheName: nil)
        
        // initialize long press gesture recognizer
        let longPressRecongnizer = UILongPressGestureRecognizer(target: self, action: #selector(self.addPinToMap(_:)))
        longPressRecongnizer.minimumPressDuration = 1
        self.mapView.addGestureRecognizer(longPressRecongnizer)
        
        mapView.delegate = self
        
        //load saved pins
        self.loadSavedPins()
    }
    
    //MARK: handle long presses by adding an annotation to the map
    
    @objc func addPinToMap(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            //get the coordinates for the location
            let touchPoint = gesture.location(in: mapView)
            let coordinates = mapView.convert(touchPoint, toCoordinateFrom: mapView)
            
            //create an annotation and keep a hold of the reference
            currentAnnotation = MKPointAnnotation()
            currentAnnotation?.coordinate = coordinates
            
            //add the annotation on the map
            self.mapView.addAnnotation(currentAnnotation!)
            break
        case .ended:
            if let currentAnnotation = currentAnnotation {
                //create a new pin
                let _ = Pin(latitude: currentAnnotation.coordinate.latitude, longitude: currentAnnotation.coordinate.longitude, context: (fetchedResultsController?.managedObjectContext)!)
                annotations.append(currentAnnotation)
            }
            
            //clear the current annotation
            currentAnnotation = nil
            break
        case .changed:
            //move the annotation on the map
            if let currentAnnotation = currentAnnotation {
                let touchPoint = gesture.location(in: mapView)
                let coordinates = mapView.convert(touchPoint, toCoordinateFrom: mapView)
                currentAnnotation.coordinate = coordinates
            }
            break
        default:
            break
        }
    }
    
    //MARK: load saved pins and place annotations to the map
    
    func loadSavedPins() {
        executeSearch()
        
        for pin in (fetchedResultsController?.fetchedObjects)! as! [Pin] {
            let annotation = MKPointAnnotation()
            annotation.coordinate.latitude = pin.latitude
            annotation.coordinate.longitude = pin.longitude
            self.mapView.addAnnotation(annotation)
            self.annotations.append(annotation)
        }
    }
}

//MARK: MKMapViewDelegate

extension MapViewController: MKMapViewDelegate {
    
    //MARK: open the album view when a pin is selected
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        let photoAlbumViewController = self.storyboard!.instantiateViewController(withIdentifier: "PhotoAlbumViewController") as! PhotoAlbumViewController
        photoAlbumViewController.annotations = annotations
        
        executeSearch()
        
        for pin in (fetchedResultsController?.fetchedObjects)! as! [Pin] {
            //check if the pin's coordinates match the given annotation's coordinates
            if (pin.latitude == view.annotation?.coordinate.latitude && pin.longitude == view.annotation?.coordinate.longitude) {
                
                //set the pin the albumviewcontroller
                photoAlbumViewController.selectedPin = pin
                break
            }
        }
        
        //open the album view
        self.navigationController!.pushViewController(photoAlbumViewController, animated: true)
    }
}

// MARK: - MapViewController (Fetches)

extension MapViewController {
    func executeSearch() {
        if let fc = fetchedResultsController {
            do {
                try fc.performFetch()
            } catch let e as NSError {
                print("Error while trying to perform a search: \n\(e)\n\(String(describing: fetchedResultsController))")
            }
        }
    }
}
