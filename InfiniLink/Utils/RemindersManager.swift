//
//  RemindersManager.swift
//  InfiniLink
//
//  Created by Liam Willey on 10/14/24.
//

import EventKit
import SwiftUI

class RemindersManager: ObservableObject {
    static let shared = RemindersManager()
    
    @Published var reminders = [EKReminder]()
    @Published var isAuthorized = false
    
    var eventStore = EKEventStore()
    
    @AppStorage("enableReminders") var enableReminders = true
    
    func fetchAllReminders() {
        if enableReminders {
            eventStore.fetchReminders(matching: eventStore.predicateForReminders(in: nil)) { reminders in
                guard let reminders = reminders else { return }
                
                DispatchQueue.main.async {
                    self.reminders = reminders
                }
            }
        }
    }
    
    func completeReminder(_ reminder: EKReminder) {
        reminder.isCompleted = true
        
        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func requestReminderAccess() {
        eventStore.requestAccess(to: .reminder) { granted, error in
            if let error = error {
                print(error.localizedDescription)
            } else if granted {
                DispatchQueue.main.async {
                    self.isAuthorized = true
                    self.fetchAllReminders()
                }
            }
        }
    }
}
