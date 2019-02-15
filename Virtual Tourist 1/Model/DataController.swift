//
//  DataController.swift
//  Virtual Tourist 1
//
//  Created by hind on 2/10/19.
//  Copyright © 2019 hind. All rights reserved.
//

import Foundation
import CoreData

class DataController {
    
    let persistentContainer : NSPersistentContainer
    var backgroundContext: NSManagedObjectContext!
    
    var viewContext :NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    init(modelName:String) {
        persistentContainer = NSPersistentContainer(name: modelName)
        
        backgroundContext = persistentContainer.newBackgroundContext()
    }
    
    func configureContext(){
        backgroundContext = persistentContainer.newBackgroundContext()
        
        viewContext.automaticallyMergesChangesFromParent = true
        backgroundContext.automaticallyMergesChangesFromParent = true
        
        backgroundContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        viewContext.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
    }
    func load(Completion :(() -> Void)? = nil) {
        persistentContainer.loadPersistentStores { (storeDescription, error) in
            guard error == nil else{
                fatalError((error?.localizedDescription)!)
            }
            self.configureContext()
             self.autoSaveViewContext()
            Completion?()
        }
    }
    
}
    // MARK: - Autosaving
    extension DataController {
        func autoSaveViewContext(interval:TimeInterval = 30) {
            print("autosaving")
            
            guard interval > 0 else {
                print("cannot set negative autosave interval")
                return
            }
            
            if viewContext.hasChanges {
                try? viewContext.save()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                self.autoSaveViewContext(interval: interval)
            }
        }
}



