//
// Copyright © 2020 Stream.io Inc. All rights reserved.
//

import CoreData
import Foundation

extension Client {
    /// Creates a new `ChannelListController` with the provided channel query.
    ///
    /// - Parameter query: The query specify the filter and sorting of the channels the controller should fetch.
    /// - Returns: A new instance of `ChannelController`.
    ///
    public func channelListController(query: ChannelListQuery) -> ChannelListControllerGeneric<ExtraData> {
        .init(query: query, client: self)
    }
}

/// A convenience typealias for `ChannelListControllerGeneric` with `DefaultDataTypes`
public typealias ChannelListController = ChannelListControllerGeneric<DefaultDataTypes>

/// `ChannelListController` allows observing and mutating the list of channels specified by a channel query.
///
///  ... you can do this and that
///
public class ChannelListControllerGeneric<ExtraData: ExtraDataTypes>: Controller, DelegateCallbable {
    /// The query specifying and filtering the list of channels.
    public let query: ChannelListQuery
    
    /// The `ChatClient` instance this controller belongs to.
    public let client: Client<ExtraData>
    
    /// The channels matching the query. To observe updates in the list, set your class as a delegate of this controller.
    public private(set) lazy var channels: [ChannelModel<ExtraData>] = {
        log.warning("Accessing `channels` before calling `startUpdating()` always results in an empty array.")
        return []
    }()
    
    /// The worker used to fetch the remote data and communicate with servers.
    private lazy var worker: ChannelListQueryUpdater<ExtraData> = self.environment
        .channelQueryUpdaterBuilder(client.databaseContainer,
                                    client.webSocketClient,
                                    client.apiClient)
    
    /// A type-erased delegate.
    private(set) var anyDelegate: AnyChannelListControllerDelegate<ExtraData>?
    
    /// Used for observing the database for changes.
    private(set) lazy var fetchedResultsController: NSFetchedResultsController<ChannelDTO> = {
        let request = ChannelDTO.channelListFetchRequest(query: self.query)
        let frc = NSFetchedResultsController<ChannelDTO>(fetchRequest: request,
                                                         managedObjectContext: client.databaseContainer.viewContext,
                                                         sectionNameKeyPath: nil,
                                                         cacheName: nil)
        frc.delegate = self.changeAggregator
        return frc
    }()
    
    /// Acts like the `NSFetchedResultsController`'s delegate and aggregates the reported changes into easily consumable form.
    private(set) lazy var changeAggregator: ChangeAggregator<ChannelDTO, ChannelModel<ExtraData>> = {
        let aggregator: ChangeAggregator<ChannelDTO, ChannelModel<ExtraData>>
            = self.environment.changeAggregatorBuilder(ChannelModel<ExtraData>.create)
        
        aggregator.onChange = { [unowned self] (changes: [Change<ChannelModel<ExtraData>>]) in
            self.channels = self.fetchedResultsController.fetchedObjects!.lazy.map(ChannelModel<ExtraData>.create(fromDTO:))
            self.delegateCallback {
                $0?.controller(self, didChangeChannels: changes)
            }
        }
        
        return aggregator
    }()
    
    private let environment: Environment
    
    /// Creates a new `ChannelListController`.
    ///
    /// - Parameters:
    ///   - query: The query used for filtering the channels.
    ///   - client: The `Client` instance this controller belongs to.
    init(query: ChannelListQuery, client: Client<ExtraData>, environment: Environment = .init()) {
        self.client = client
        self.query = query
        self.environment = environment
    }
    
    /// Starts updating the results.
    ///
    /// 1. **Synchronously** loads the data for the referenced objects from the local cache. These data are immediately available in
    /// the `channels` property of the controller once this method returns. Any further changes to the data are communicated
    /// using `delegate`.
    ///
    /// 2. It also **asynchronously** fetches the latest version of the data from the servers. Once the remote fetch is completed,
    /// the completion block is called. If the updated data differ from the locally cached ones, the controller uses the `delegate`
    /// methods to inform about the changes.
    ///
    /// - Parameter completion: Called when the controller has finished fetching remote data. If the data fetching fails, the `error`
    /// variable contains more details about the problem.
    public func startUpdating(_ completion: ((_ error: Error?) -> Void)? = nil) {
        do {
            try fetchedResultsController.performFetch()
        } catch {
            log.error("Failed to perform fetch request with error: \(error). This is an internal error.")
            completion?(ClientError.FetchFailed())
            return
        }
        
        channels = fetchedResultsController.fetchedObjects!.lazy.map(ChannelModel<ExtraData>.create)
        
        delegateCallback {
            $0?.controllerWillStartFetchingRemoteData(self)
        }
        
        worker.update(channelListQuery: query) { [weak self] error in
            guard let self = self else { return }
            self.delegateCallback {
                $0?.controllerDidStopFetchingRemoteData(self, withError: error)
            }
            completion?(error)
        }
    }
    
    /// Sets the provided object as a delegate of this controller.
    ///
    /// - Note: If you don't use custom extra data types, you can set the delegate directly using `controller.delegate = self`.
    /// Due to the current limits of Swift and the way it handles protocols with associated types, it's required to use this
    /// method to set the delegate, if you're using custom extra data types.
    ///
    /// - Parameter delegate: The object used as a delegate. It's referenced weakly, so you need to keep the object
    /// alive if you want keep receiving updates.
    public func setDelegate<Delegate: ChannelListControllerDelegateGeneric>(_ delegate: Delegate)
        where Delegate.ExtraData == ExtraData {
        anyDelegate = AnyChannelListControllerDelegate(delegate)
    }
}

extension ChannelListControllerGeneric {
    struct Environment {
        var channelQueryUpdaterBuilder: (
            _ database: DatabaseContainer,
            _ webSocketClient: WebSocketClient,
            _ apiClient: APIClient
        ) -> ChannelListQueryUpdater<ExtraData> = ChannelListQueryUpdater.init
        
        var changeAggregatorBuilder: (_ itemBuilder: @escaping (ChannelDTO) -> ChannelModel<ExtraData>?)
            -> ChangeAggregator<ChannelDTO, ChannelModel<ExtraData>> = {
                ChangeAggregator<ChannelDTO, ChannelModel<ExtraData>>(itemCreator: $0)
            }
    }
}

extension ChannelListControllerGeneric where ExtraData == DefaultDataTypes {
    /// Set the delegate of `ChannelListController` to observe the changes in the system.
    ///
    /// - Note: The delegate can be set directly only if you're **not** using custom extra data types. Due to the current
    /// limits of Swift and the way it handles protocols with associated types, it's required to use `setDelegate` method
    /// instead to set the delegate, if you're using custom extra data types.
    public weak var delegate: ChannelListControllerDelegate? {
        set { anyDelegate = AnyChannelListControllerDelegate(newValue) }
        get { anyDelegate?.wrappedDelegate as? ChannelListControllerDelegate }
    }
}

/// `ChannelListController` uses this protocol to communicate changes to its delegate.
///
/// This protocol can be used only when no custom extra data are specified. If you're using custom extra data types,
/// please use `GenericChannelListController` instead.
public protocol ChannelListControllerDelegate: ControllerRemoteActivityDelegate {
    func controller(_ controller: ChannelListControllerGeneric<DefaultDataTypes>, didChangeChannels changes: [Change<Channel>])
}

public extension ChannelListControllerDelegate {
    func controller(_ controller: ChannelListControllerGeneric<DefaultDataTypes>, didChangeChannels changes: [Change<Channel>]) {}
}

/// `ChannelListController` uses this protocol to communicate changes to its delegate.
///
/// If you're **not** using custom extra data types, you can use a convenience version of this protocol
/// named `ChannelListControllerDelegate`, which hides the generic types, and make the usage easier.
public protocol ChannelListControllerDelegateGeneric: ControllerRemoteActivityDelegate {
    associatedtype ExtraData: ExtraDataTypes
    func controller(
        _ controller: ChannelListControllerGeneric<ExtraData>,
        didChangeChannels changes: [Change<ChannelModel<ExtraData>>]
    )
}

public extension ChannelListControllerDelegateGeneric {
    func controller(_ controller: ChannelListControllerGeneric<DefaultDataTypes>,
                    didChangeChannels changes: [Change<ChannelModel<ExtraData>>]) {}
}

extension ClientError {
    public class FetchFailed: Error {
        public var localizedDescription: String = "Failed to perform fetch request. This is an internal error."
    }
}

// MARK: - Delegate type eraser

class AnyChannelListControllerDelegate<ExtraData: ExtraDataTypes>: ChannelListControllerDelegateGeneric {
    private var _controllerDidChangeChannels: (ChannelListControllerGeneric<ExtraData>, [Change<ChannelModel<ExtraData>>]) -> Void
    private var _controllerWillStartFetchingRemoteData: (Controller) -> Void
    private var _controllerDidStopFetchingRemoteData: (Controller, Error?) -> Void
    
    weak var wrappedDelegate: AnyObject?
    
    init(
        wrappedDelegate: AnyObject?,
        controllerWillStartFetchingRemoteData: @escaping (Controller) -> Void,
        controllerDidStopFetchingRemoteData: @escaping (Controller, Error?) -> Void,
        controllerDidChangeChannels: @escaping (ChannelListControllerGeneric<ExtraData>, [Change<ChannelModel<ExtraData>>]) -> Void
    ) {
        self.wrappedDelegate = wrappedDelegate
        _controllerWillStartFetchingRemoteData = controllerWillStartFetchingRemoteData
        _controllerDidStopFetchingRemoteData = controllerDidStopFetchingRemoteData
        _controllerDidChangeChannels = controllerDidChangeChannels
    }
    
    func controllerWillStartFetchingRemoteData(_ controller: Controller) {
        _controllerWillStartFetchingRemoteData(controller)
    }
    
    func controllerDidStopFetchingRemoteData(_ controller: Controller, withError error: Error?) {
        _controllerDidStopFetchingRemoteData(controller, error)
    }
    
    func controller(
        _ controller: ChannelListControllerGeneric<ExtraData>,
        didChangeChannels changes: [Change<ChannelModel<ExtraData>>]
    ) {
        _controllerDidChangeChannels(controller, changes)
    }
}

extension AnyChannelListControllerDelegate {
    convenience init<Delegate: ChannelListControllerDelegateGeneric>(_ delegate: Delegate) where Delegate.ExtraData == ExtraData {
        self.init(wrappedDelegate: delegate,
                  controllerWillStartFetchingRemoteData: { [weak delegate] in delegate?.controllerWillStartFetchingRemoteData($0) },
                  controllerDidStopFetchingRemoteData: { [weak delegate] in
                      delegate?.controllerDidStopFetchingRemoteData($0, withError: $1)
                  },
                  controllerDidChangeChannels: { [weak delegate] in delegate?.controller($0, didChangeChannels: $1) })
    }
}

extension AnyChannelListControllerDelegate where ExtraData == DefaultDataTypes {
    convenience init(_ delegate: ChannelListControllerDelegate?) {
        self.init(wrappedDelegate: delegate,
                  controllerWillStartFetchingRemoteData: { [weak delegate] in delegate?.controllerWillStartFetchingRemoteData($0) },
                  controllerDidStopFetchingRemoteData: { [weak delegate] in
                      delegate?.controllerDidStopFetchingRemoteData($0, withError: $1)
                  },
                  controllerDidChangeChannels: { [weak delegate] in delegate?.controller($0, didChangeChannels: $1) })
    }
}
