//
//  Photo+CoreDataClass.swift
//  Virtual Tourist
//

import Foundation
import CoreData

@objc(Photo)
public class Photo: NSManagedObject {

    // MARK: Initializer
    
    convenience init(imageUrl: String, imageData: NSData?, context: NSManagedObjectContext) {
        if let ent = NSEntityDescription.entity(forEntityName: "Photo", in: context) {
            self.init(entity: ent, insertInto: context)
            self.imageUrl = imageUrl
            self.imageData = imageData
        } else {
            fatalError("Unable To Find Entity Name!")
        }
    }    
}
