//
//  PhotoAlbumCollectionViewCell.swift
//  Virtual Tourist
//

import Foundation
import UIKit

class PhotoAlbumCollectionViewCell: UICollectionViewCell {
    
    // MARK: Outlets
    
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var label: UILabel!
    
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    
    let stack = (UIApplication.shared.delegate as! AppDelegate).stack
    
    //MARK: set image to the image view. Use either the image from the database or from the internet
    
    func setImage(photo: Photo) {
        
        if let imageData = photo.imageData { //use existing image data
            DispatchQueue.main.async {
                //update image view and stop the progress indicator
                self.imageView.image = UIImage(data: imageData as Data)
                self.activityIndicatorView.stopAnimating()
            }
        } else { //download image data
            downloadImage(photo: photo)
        }
    }
    
    //MARK: download the image from the associated url
    
    private func downloadImage(photo: Photo) {
        guard let urlString = photo.imageUrl else {
            print("no url for downloading image")
            return
        }
        FlickrClient.sharedInstance().downloadImage(urlString: urlString, completion: { (data, error) in
            if let error = error {
                print("error \(String(describing: error))")
            } else {
                guard data != nil else {
                    print("image data was nil")
                    return
                }
                //update the image data
                photo.imageData = data as NSData?
                
                DispatchQueue.main.async {
                    
                    //update the image view
                    self.imageView.image = UIImage(data: photo.imageData! as Data)
                    
                    //hide the progress indicator
                    self.activityIndicatorView.stopAnimating()
                }
            }
        })
    }
}
