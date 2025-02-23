//
//  OTFCareKitSample.swift
//  OTFCareKitSample
//
//  Created by Miroslav Kutak on 05/07/21.
//

import Foundation
import OTFCareKit
import OTFCareKitStore
import Contacts
import UIKit
#if HEALTH
import HealthKit
#endif

public protocol OTFCareKitSampleProtocol {
    func launchIn(_ window: UIWindow?)
}

public class OTFCareKitSample: OTFCareKitSampleProtocol {
    lazy private(set) var coreDataStore = OCKStore(name: "SampleAppStore", type: .inMemory)

    lazy private(set) var healthKitStore = OCKHealthKitPassthroughStore(store: coreDataStore)

    var window: UIWindow?

    static public let shared: OTFCareKitSampleProtocol = OTFCareKitSample()

    lazy private(set) var synchronizedStoreManager: OCKSynchronizedStoreManager = {
        let coordinator = OCKStoreCoordinator()
        #if HEALTH
        coordinator.attach(eventStore: healthKitStore)
        #endif
        coordinator.attach(store: coreDataStore)
        return OCKSynchronizedStoreManager(wrapping: coordinator)
    }()

    public func launchIn(_ window: UIWindow?) {
        coreDataStore.populateSampleData()
        #if HEALTH
        healthKitStore.populateSampleData()
        #endif
        self.launchControllerIn(window: window)
    }

    private func launchControllerIn(window: UIWindow?) {
        let careViewController = UINavigationController(rootViewController: CareViewController(storeManager: synchronizedStoreManager))

        let permissionViewController = UIViewController()
        permissionViewController.view.backgroundColor = .white
        window?.rootViewController = permissionViewController
        window?.tintColor = UIColor { $0.userInterfaceStyle == .light ? #colorLiteral(red: 0.9960784314, green: 0.3725490196, blue: 0.368627451, alpha: 1) : #colorLiteral(red: 0.8627432641, green: 0.2630574384, blue: 0.2592858295, alpha: 1) }
        window?.makeKeyAndVisible()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.healthKitStore.requestHealthKitPermissionsForAllTasksInStore { _ in
                DispatchQueue.main.async {
                    window?.rootViewController = careViewController
                }
            }
        }
    }
}

private extension OCKStore {
    // Adds tasks and contacts into the store
    func populateSampleData() {
        let thisMorning = Calendar.current.startOfDay(for: Date())
        let aFewDaysAgo = Calendar.current.date(byAdding: .day, value: -4, to: thisMorning)!
        let beforeBreakfast = Calendar.current.date(byAdding: .hour, value: 8, to: aFewDaysAgo)!
        let afterLunch = Calendar.current.date(byAdding: .hour, value: 14, to: aFewDaysAgo)!

        let schedule = OCKSchedule(composing: [
            OCKScheduleElement(start: beforeBreakfast, end: nil,
                               interval: DateComponents(day: 1)),

            OCKScheduleElement(start: afterLunch, end: nil,
                               interval: DateComponents(day: 2))
        ])

        var doxylamine = OCKTask(id: "doxylamine", title: "Take Doxylamine",
                                 carePlanUUID: nil, schedule: schedule)
        doxylamine.instructions = "Take 25mg of doxylamine when you experience nausea."
        doxylamine.asset = "pills"
        let nauseaSchedule = OCKSchedule(composing: [
            OCKScheduleElement(start: beforeBreakfast, end: nil, interval: DateComponents(day: 1),
                               text: "Anytime throughout the day", targetValues: [], duration: .allDay)
            ])

        var nausea = OCKTask(id: "nausea", title: "Track your nausea",
                             carePlanUUID: nil, schedule: nauseaSchedule)
        nausea.impactsAdherence = false
        nausea.instructions = "Tap the button below anytime you experience nausea."

        let kegelElement = OCKScheduleElement(start: beforeBreakfast, end: nil, interval: DateComponents(day: 2))
        let kegelSchedule = OCKSchedule(composing: [kegelElement])
        var kegels = OCKTask(id: "kegels", title: "Kegel Exercises", carePlanUUID: nil, schedule: kegelSchedule)
        kegels.impactsAdherence = true
        kegels.instructions = "Perform kegel exercies"

        addTasks([nausea, doxylamine, kegels], callbackQueue: .main, completion: nil)

        var contact1 = OCKContact(id: "jane", givenName: "Jane",
                                  familyName: "Daniels", carePlanUUID: nil)
        contact1.asset = "JaneDaniels"
        contact1.title = "Family Practice Doctor"
        contact1.role = "Dr. Daniels is a family practice doctor with 8 years of experience."
        contact1.emailAddresses = [OCKLabeledValue(label: CNLabelEmailiCloud, value: "janedaniels@icloud.com")]
        contact1.phoneNumbers = [OCKLabeledValue(label: CNLabelWork, value: "(324) 555-7415")]
        contact1.messagingNumbers = [OCKLabeledValue(label: CNLabelWork, value: "(324) 555-7415")]

        contact1.address = {
            let address = OCKPostalAddress()
            address.street = "2598 Reposa Way"
            address.city = "San Francisco"
            address.state = "CA"
            address.postalCode = "94127"
            return address
        }()

        var contact2 = OCKContact(id: "matthew", givenName: "Matthew",
                                  familyName: "Reiff", carePlanUUID: nil)
        contact2.asset = "MatthewReiff"
        contact2.title = "OBGYN"
        contact2.role = "Dr. Reiff is an OBGYN with 13 years of experience."
        contact2.phoneNumbers = [OCKLabeledValue(label: CNLabelWork, value: "(324) 555-7415")]
        contact2.messagingNumbers = [OCKLabeledValue(label: CNLabelWork, value: "(324) 555-7415")]
        contact2.address = {
            let address = OCKPostalAddress()
            address.street = "396 El Verano Way"
            address.city = "San Francisco"
            address.state = "CA"
            address.postalCode = "94127"
            return address
        }()

        addContacts([contact1, contact2])
    }
}

extension OCKHealthKitPassthroughStore {
    #if HEALTH
    func populateSampleData() {
        let schedule = OCKSchedule.dailyAtTime(
            hour: 8, minutes: 0, start: Date(), end: nil, text: nil,
            duration: .hours(12), targetValues: [OCKOutcomeValue(2_000.0, units: "Steps")])

        let steps = OCKHealthKitTask(
            id: "steps",
            title: "Steps",
            carePlanUUID: nil,
            schedule: schedule,
            healthKitLinkage: OCKHealthKitLinkage(
                quantityIdentifier: .stepCount,
                quantityType: .cumulative,
                unit: .count()))

        addTasks([steps]) { result in
            switch result {
            case .success:
                print("Added tasks into HealthKitPassthroughStore!")
            case .failure(let error):
                print("Error: \(error)")
            }
        }
    }
    #endif
}
