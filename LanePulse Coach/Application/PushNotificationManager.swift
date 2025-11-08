//
//  PushNotificationManager.swift
//  LanePulse Coach
//
//  Manages push notification registration and delegate callbacks.
//

import Foundation
import UserNotifications
import UIKit

protocol NotificationManaging: UNUserNotificationCenterDelegate {
    func configureNotificationSupport()
    func registerForRemoteNotifications(application: UIApplication)
    func didRegisterForRemoteNotifications(with deviceToken: Data)
    func didFailToRegisterForRemoteNotifications(error: Error)
}

final class PushNotificationManager: NSObject, NotificationManaging {
    private enum CategoryIdentifier {
        static let sessionReminder = "com.lanepulse.coach.notifications.session-reminder"
    }

    private let notificationCenter: UNUserNotificationCenter
    private let logger: Logging
    private let widgetRefresher: WidgetRefreshing
    private var didConfigure = false

    init(notificationCenter: UNUserNotificationCenter = .current(),
         logger: Logging,
         widgetRefresher: WidgetRefreshing) {
        self.notificationCenter = notificationCenter
        self.logger = logger
        self.widgetRefresher = widgetRefresher
        super.init()
    }

    func configureNotificationSupport() {
        guard !didConfigure else { return }
        notificationCenter.delegate = self
        notificationCenter.setNotificationCategories(makeCategories())
        didConfigure = true
        logger.log(level: .debug, message: "Configured notification center delegate")
    }

    func registerForRemoteNotifications(application: UIApplication) {
        Task { [weak self] in
            guard let self else { return }
            let settings = await notificationCenter.notificationSettings()
            switch settings.authorizationStatus {
            case .notDetermined:
                await requestAuthorization(application: application)
            case .authorized, .provisional, .ephemeral:
                await MainActor.run {
                    application.registerForRemoteNotifications()
                }
                logger.log(level: .info, message: "Remote notification registration requested")
            case .denied:
                logger.log(level: .warning, message: "Notification permission denied; remote notifications disabled")
            @unknown default:
                logger.log(level: .warning, message: "Unknown notification authorization status encountered")
            }
        }
    }

    func didRegisterForRemoteNotifications(with deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        logger.log(level: .info, message: "Received APNs token", metadata: ["token": token])
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        logger.log(level: .error, message: "Failed to register for remote notifications: \(error.localizedDescription)")
    }

    private func requestAuthorization(application: UIApplication) async {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                logger.log(level: .info, message: "User granted notification permissions")
                await MainActor.run {
                    application.registerForRemoteNotifications()
                }
            } else {
                logger.log(level: .warning, message: "User declined notification permissions")
            }
        } catch {
            logger.log(level: .error, message: "Notification authorization request failed: \(error.localizedDescription)")
        }
    }

    private func makeCategories() -> Set<UNNotificationCategory> {
        let startAction = UNNotificationAction(identifier: "session.start",
                                               title: "Session öffnen",
                                               options: [.foreground])
        let category = UNNotificationCategory(identifier: CategoryIdentifier.sessionReminder,
                                              actions: [startAction],
                                              intentIdentifiers: [],
                                              options: [.customDismissAction])
        return [category]
    }
}

extension PushNotificationManager {
    func scheduleLocalReminderIfNeeded(title: String, body: String, at date: Date) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = CategoryIdentifier.sessionReminder

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(date.timeIntervalSinceNow, 1), repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: trigger)
        do {
            try await notificationCenter.add(request)
            logger.log(level: .debug, message: "Scheduled local reminder", metadata: ["fireDate": "\(date)"])
        } catch {
            logger.log(level: .error, message: "Failed to schedule local reminder: \(error.localizedDescription)")
        }
    }
}

extension PushNotificationManager {
    func clearAllPendingNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
        logger.log(level: .debug, message: "Cleared pending and delivered notifications")
    }
}

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        widgetRefresher.reloadAll()
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        logger.log(level: .debug, message: "Received notification response", metadata: ["action": response.actionIdentifier])
        widgetRefresher.reloadAll()
        completionHandler()
    }
}
