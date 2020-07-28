//
// Copyright © 2020 Stream.io Inc. All rights reserved.
//

import CoreData
import Foundation

/// Observers the storage for messages pending send and sends them.
class MessageSender: Worker, NSFetchedResultsControllerDelegate {
    private lazy var frc: NSFetchedResultsController = NSFetchedResultsController(fetchRequest: MessageDTO
        .fetchRequestForMessagesPendingSend(),
                                                                                  managedObjectContext: self.database
            .backgroundReadOnlyContext,
                                                                                  sectionNameKeyPath: nil,
                                                                                  cacheName: nil)
    
    override init(database: DatabaseContainer, webSocketClient: WebSocketClient, apiClient: APIClient) {
        super.init(database: database, webSocketClient: webSocketClient, apiClient: apiClient)
        
        frc.delegate = self
        do {
            try frc.performFetch()
        } catch {
            log.error(error)
        }
    }
}
