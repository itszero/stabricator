//
//  StatusMenuController.swift
//  weatherbar
//
//  Created by Dan Hill on 10/10/17.
//  Copyright © 2017 Dan Hill. All rights reserved.
//

import Cocoa

class StatusMenuController: NSObject {
    let INSERTION_INDEX = 2

    @IBOutlet weak var statusMenu: NSMenu!

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    // TODO: get url and token from somewhere else
    let phab = Phabricator(phabricatorUrl: Constants.PHABRICATOR_URL, apiToken: Constants.API_TOKEN)
    
    @IBAction func refreshClicked(_ sender: Any) {
        refresh()
    }

    @IBAction func quitClicked(_ sender: Any) {
        NSApplication.shared.terminate(self)
    }
    
    override func awakeFromNib() {
        let icon = NSImage(named: NSImage.Name(rawValue: "knife"))
        icon?.isTemplate = true
        statusItem.image = icon
        statusItem.menu = statusMenu
        
        refresh()
    }
    
    private func refresh() {
        phab.fetchActiveDiffs() { response in
            self.onDiffsRefreshed(response: response)
            
            // TODO: have time be configurable
            let deadlineTime = DispatchTime.now() + .seconds(60)
            DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
                self.refresh()
            }
        }
    }

    private func onDiffsRefreshed(response: Response) {
        // update title on main thread
        DispatchQueue.main.async(execute: {
            self.statusItem.title = "\(response.result.data.count)"
        })
        
        
        print("Fetched \(response.result.data.count) active diffs")
        
        // clear out last update's menu items
        while (statusMenu.items.count > INSERTION_INDEX + 1) {
            statusMenu.removeItem(at: INSERTION_INDEX)
        }
        
        
        // assemble by status
        var categories = [String: [Diff]]()
        for diff in response.result.data {
            let status = diff.fields.status.value
            if categories[status] == nil {
                categories[status] = [Diff]()
            }
            categories[status]?.append(diff)
        }
        
        // insert new ones
        for (_, diffs) in categories {
            let title = diffs[0].fields.status.name
            let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            insertMenuItem(menuItem: header)

            for diff in diffs {
                let row = NSMenuItem(title: diff.fields.title, action: #selector(launchUrl), keyEquivalent: "")
                row.target = self
                row.representedObject = diff
                insertMenuItem(menuItem: row)
            }
            insertMenuItem(menuItem: NSMenuItem.separator())
        }
    }
    
    @objc private func launchUrl(_ menuItem: NSMenuItem) {
        let diff = menuItem.representedObject as! Diff
        let urlString = "https://phabricator.robinhood.com/D\(diff.id)"
        let url = URL(string: urlString)
        NSWorkspace.shared.open(url!)
    }
    
    private func insertMenuItem(menuItem: NSMenuItem) {
        statusMenu.insertItem(menuItem, at: statusMenu.items.count - 1)
    }
}
