//
//  NotificationsSettingsView.swift
//  InfiniLink
//
//  Created by Liam Willey on 10/4/24.
//

import SwiftUI

struct NotificationsSettingsView: View {
    @AppStorage("waterReminder") var waterReminder = true
    @AppStorage("waterReminderAmount") var waterReminderAmount = 7
    @AppStorage("standUpReminder") var standUpReminder = true
    @AppStorage("notifyOnReconnect") var notifyOnReconnect = false // Update to have same string as "first connect" setting in old app?
    
    @AppStorage("remindOnStepGoalCompletion") var remindOnStepGoalCompletion = true
    @AppStorage("remindOnCaloriesGoalCompletion") var remindOnCaloriesGoalCompletion = true
    @AppStorage("remindOnExerciseTimeGoalCompletion") var remindOnExerciseTimeGoalCompletion = true
    
    var body: some View {
        List {
            Section(header: Text("Health"), footer: Text("Receive a reminder to drink water for the set amount of times a day.")) {
                Toggle("Water Reminder", isOn: $waterReminder)
                if waterReminder {
                    Picker("Interval", selection: $waterReminderAmount) {
                        ForEach(0..<9) { amount in
                            Text("\(amount + 1) time\(amount == 1 ? "" : "s")")
                        }
                    }
                }
            }
            Section(footer: Text("Have your watch remind you when to stand up if you've been sedentary for too long.")) {
                Toggle("Stand-up Reminder", isOn: $standUpReminder)
            }
            Section(header: Text("Goals"), footer: Text("Get notified when you reach your daily fitness goals.")) {
                Toggle("Steps", isOn: $remindOnStepGoalCompletion)
                Toggle("Calories", isOn: $remindOnCaloriesGoalCompletion)
                Toggle("Exercise Time", isOn: $remindOnExerciseTimeGoalCompletion)
            }
            Section("Other") {
                Toggle("Notify on Reconnect", isOn: $notifyOnReconnect)
            }
        }
        .navigationTitle("Notifications")
    }
}

#Preview {
    NotificationsSettingsView()
}