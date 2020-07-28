//
// Copyright © 2020 Stream.io Inc. All rights reserved.
//

import CoreData

/// This enum describes the changes of the given collections of items.
public enum Change<Item> {
    /// A new item was inserted on the given index path.
    case insert(_ item: Item, index: IndexPath)
    
    /// An item was moved from `fromIndex` to `toIndex`. Moving an item also automatically generates
    /// an `update` change.
    case move(_ item: Item, fromIndex: IndexPath, toIndex: IndexPath)
    
    /// An item was updated at the given `index`. An `update` change is also automatically generated by moving an item.
    case update(_ item: Item, index: IndexPath)
    
    /// An item was removed from the given `index`.
    case remove(_ item: Item, index: IndexPath)
}

extension Change: Equatable where Item: Equatable {}

/// When this object is set as `NSFetchedResultsControllerDelegate`, it aggregates the callbacks from the fetched results
/// controller and forwards them in the way of `[Change<Item>]`. You can set the `onChange` callback to receive these updates.
class ChangeAggregator<DTO: NSManagedObject, Item>: NSObject, NSFetchedResultsControllerDelegate {
    // TODO: Extend this to also provide `CollectionDifference` and `NSDiffableDataSourceSnapshot`
    
    /// Used for converting the `DTO`s provided by `FetchResultsController` to the resulting `Item`.
    let itemCreator: (DTO) -> Item?
    
    /// Called with the aggregated changes after `FetchResultsController` calls controllerDidChangeContent` on its delegate.
    var onChange: (([Change<Item>]) -> Void)?
    
    /// An array of changes in the current update. It gets reset every time `controllerWillChangeContent` is called, and
    /// published to the observer when `controllerDidChangeContent` is called.
    private var currentChanges: [Change<Item>] = []
    
    /// Creates a new `ChangeAggregator`.
    ///
    /// - Parameter itemCreator: Used for converting the `NSManagedObject`s provided by `FetchResultsController`
    /// to the resulting `Item`.
    init(itemCreator: @escaping (DTO) -> Item?) {
        self.itemCreator = itemCreator
    }
    
    // MARK: - NSFetchedResultsControllerDelegate
    
    // This should ideally be in the extensions but it's not possible to implement @objc methods in extensions of generic types.
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        currentChanges = []
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                    didChange anObject: Any,
                    at indexPath: IndexPath?,
                    for type: NSFetchedResultsChangeType,
                    newIndexPath: IndexPath?) {
        guard let dto = anObject as? DTO, let item = itemCreator(dto) else {
            log.warning("Skipping the update from DB because the DTO can't be converted to the model object.")
            return
        }
        
        switch type {
        case .insert:
            guard let index = newIndexPath else {
                log.warning("Skipping the update from DB because `newIndexPath` is missing for `.insert` change.")
                return
            }
            currentChanges.append(.insert(item, index: index))
            
        case .move:
            guard let fromIndex = indexPath, let toIndex = newIndexPath else {
                log.warning("Skipping the update from DB because `indexPath` or `newIndexPath` are missing for `.move` change.")
                return
            }
            currentChanges.append(.move(item, fromIndex: fromIndex, toIndex: toIndex))
            currentChanges.append(.update(item, index: toIndex))
            
        case .update:
            guard let index = indexPath else {
                log.warning("Skipping the update from DB because `indexPath` is missing for `.update` change.")
                return
            }
            currentChanges.append(.update(item, index: index))
            
        case .delete:
            guard let index = indexPath else {
                log.warning("Skipping the update from DB because `indexPath` is missing for `.delete` change.")
                return
            }
            currentChanges.append(.remove(item, index: index))
            
        default:
            break
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        onChange?(currentChanges)
    }
}
