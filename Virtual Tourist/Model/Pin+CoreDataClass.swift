//
//  Pin+CoreDataClass.swift
//  Virtual Tourist
//

import Foundation
import CoreData

@objc(Pin)
public class Pin: NSManagedObject {

    // MARK: Initializer
    
    convenience init(latitude: Double, longitude: Double, context: NSManagedObjectContext) {
        if let ent = NSEntityDescription.entity(forEntityName: "Pin", in: context) {
            self.init(entity: ent, insertInto: context)
            self.latitude   = latitude
            self.longitude  = longitude
        } else {
            fatalError("Unable To Find Entity Name!")
        }
    }
}
