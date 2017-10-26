//
//  PhotoAlbumViewController.swift
//  Virtual Tourist
//

import Foundation
import UIKit
import CoreData
import MapKit

class PhotoAlbumViewController: UIViewController {
    
    // MARK: Properties
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var photoAlbumView: UICollectionView!
    @IBOutlet weak var newCollectionButton: UIButton!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    
    let stack = (UIApplication.shared.delegate as! AppDelegate).stack
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Photo")
    
    var annotations: [MKPointAnnotation] = []
    var selectedPin: Pin!
    
    var fetchedResultsController : NSFetchedResultsController<NSFetchRequestResult>? {
        didSet {
            executeSearch()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        guard selectedPin != nil else {
            print("the selected pin was nil")
            return
        }
        
        //setup the flowlayout
        let space:CGFloat = 3.0
        
        let dimension = (view.frame.size.width - (2 * space)) / 3.0
        
        flowLayout.minimumInteritemSpacing = space
        flowLayout.minimumLineSpacing = space
        flowLayout.itemSize = CGSize(width: dimension, height: dimension)
        
        // Create a fetchrequest for the given pin
        fetchRequest.sortDescriptors = []
        fetchRequest.predicate = NSPredicate(format: "pin = %@", argumentArray: [selectedPin])
        
        // Create the FetchedResultsController
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: stack.context, sectionNameKeyPath: nil, cacheName: nil)
        
        //load all the pins for the mapview
        loadAnnotations()
        
        //center the mapview on the pin's coordinates
        self.mapView.centerCoordinate.latitude = selectedPin.latitude
        self.mapView.centerCoordinate.longitude = selectedPin.longitude
        
        self.photoAlbumView.delegate = self
        self.photoAlbumView.dataSource = self
        
        //load photos for the pin
        loadPhotos(for: selectedPin, completion: nil)
    }
    
    override func willMove(toParentViewController parent: UIViewController?) {
        if parent == nil {
            // Save when moving back to the map view
            stack.save()
        }
    }
    
    // MARK: load photos for the pin either from the api or from the database
    
    func loadPhotos(for pin: Pin, completion: (() -> Void)?) {
        
        //check if there are photos for the pin
        if pin.photo?.count == 0 {
            
            //download photos from the api
            FlickrClient.sharedInstance().getFlickrImages(latitude: pin.latitude, longitude: pin.longitude, page: nil, completion: { (photos, error) in
                
                guard let photos = photos, error == nil else {
                    print("there was a problem with parsing photos")
                    return
                }
                
                DispatchQueue.main.async {
                    
                    //create new photo objects, save them to the database and refresh the collection view
                    for photo in photos {
                        let imageUrlString = photo[FlickrConstants.FlickrResponseKeys.MediumURL] as? String
                        let photoObject = Photo(imageUrl: imageUrlString!, imageData: nil, context: (self.fetchedResultsController?.managedObjectContext)!)
                        photoObject.pin = pin
                        
                        self.executeSearch()
                        self.photoAlbumView.reloadData()
                    }
                    
                    //call the completion block if it is present
                    if let completion = completion {
                        completion()
                    }
                }
            })
        } else {
            //use existing photos and refresh the view
            DispatchQueue.main.async {
                self.photoAlbumView.reloadData()
            }
        }
    }
    
    // MARK: load annotations and show on the mapview
    
    func loadAnnotations() {
        for annotation in annotations {
            let newAnnotation = MKPointAnnotation()
            newAnnotation.coordinate = annotation.coordinate
            self.mapView.addAnnotation(newAnnotation)
        }
    }
    
    // MARK: handle new collection button presses
    
    @IBAction func newCollectionButtonPressed(_ sender: Any) {
        //disable the button
        newCollectionButton.isEnabled = false
        
        //delete the photos related to the pin
        for photo in selectedPin.photo! {
            self.stack.context.delete(photo as! NSManagedObject)
        }
        
        //save the changes
        self.stack.save()
        
        //load a new set of images
        self.loadPhotos(for: selectedPin, completion: { () in
            //enable the button
            self.newCollectionButton.isEnabled = true
        })
    }
}

// MARK: - UICollectionViewDataSource

extension PhotoAlbumViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let fc = fetchedResultsController {
            return fc.sections![section].numberOfObjects
        } else {
            return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let photo = fetchedResultsController?.object(at: indexPath) as! Photo
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoAlbumCollectionViewCell", for: indexPath) as! PhotoAlbumCollectionViewCell
        
        //show a progress indicator while the image data is being setup
        cell.activityIndicatorView.startAnimating()
        
        //load the image data
        cell.setImage(photo: photo)
        
        return cell
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        if let fc = fetchedResultsController {
            return (fc.sections?.count)!
        } else {
            return 0
        }
    }
}

// MARK: - UICollectionViewDelegate

extension PhotoAlbumViewController: UICollectionViewDelegate {
    
    //delete the selected photo
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let photo = fetchedResultsController?.object(at: indexPath) as! Photo
        
        //delete the photo
        self.stack.context.delete(photo)
        
        //save the changes
        self.stack.save()
        
        //update the collection view
        self.executeSearch()
        self.photoAlbumView.reloadData()
    }
}

// MARK: - CoreDataTableViewController (Fetches)

extension PhotoAlbumViewController {
    func executeSearch() {
        if let fc = fetchedResultsController {
            do {
                try fc.performFetch()
            } catch let e as NSError {
                print("Error while trying to perform a search: \n\(e)\n\(String(describing: fetchedResultsController)))")
            }
        }
    }
}
