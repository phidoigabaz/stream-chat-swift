//
//  MasterViewController.swift
//  V3SampleApp
//
//  Created by Vojta on 28/05/2020.
//  Copyright © 2020 Stream.io Inc. All rights reserved.
//

import UIKit
import StreamChatClient_v3

class MasterViewController: UITableViewController {

    lazy var channelListController: ChannelListController = chatClient
        .channelListController(query: ChannelListQuery(filter: .in("members", ["broken-waterfall-5"]), options: [.watch]))
    
    var detailViewController: DetailViewController? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        channelListController.delegate = self
        channelListController.startUpdating()
        
        // Do any additional setup after loading the view.
        navigationItem.leftBarButtonItem = editButtonItem

        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(insertNewObject(_:)))
        navigationItem.rightBarButtonItem = addButton
        if let split = splitViewController {
            let controllers = split.viewControllers
            detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
        super.viewWillAppear(animated)
    }

    @objc
    func insertNewObject(_ sender: Any) {
    }

    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            if let indexPath = tableView.indexPathForSelectedRow {
                let channel = channelListController.channels[indexPath.row]
                let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
                controller.channelId = channel.cid
                controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
                controller.navigationItem.leftItemsSupplementBackButton = true
                detailViewController = controller
            }
        }
    }

    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return channelListController.channels.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let object = channelListController.channels[indexPath.row]
        cell.textLabel?.text = object.extraData.name ?? object.cid.description
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    }
}

extension MasterViewController: ChannelListControllerDelegate {
    func controller(_ controller: ChannelListControllerGeneric<DefaultDataTypes>, didChangeChannels changes: [Change<Channel>]) {
        // Animate changes
        
        /*
         TODO: It could be nice to provide this boilerplate as an extension of UITableView. Something like:
         
            tableView.apply(changes: changes)
         
         and similarly for:
         
            collectionView.apply(changes: changes)
         */
        
        tableView.beginUpdates()
        
        for change in changes {
            switch change {
            case .insert(_, index: let index):
                tableView.insertRows(at: [index], with: .automatic)
            case .move(_, fromIndex: let fromIndex, toIndex: let toIndex):
                tableView.moveRow(at: fromIndex, to: toIndex)
            case .update(_, index: let index):
                tableView.reloadRows(at: [index], with: .automatic)
            case .remove(_, index: let index):
                tableView.deleteRows(at: [index], with: .automatic)
            }
        }
        
        tableView.endUpdates()
    }
}
