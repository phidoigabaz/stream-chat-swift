//
// Copyright © 2020 Stream.io Inc. All rights reserved.
//

import CoreData
import Foundation

class MessageEditor: Worker {
    func sendNewMessage(text: String) {
        let newMessageId = UUID().uuidString
        
        database.write { (session) in
            session as NSManagedObjectContext
        }
    }
}
