//
//  AppDelegate.swift
//  LanePulse Coach
//
//  Connects UIApplication lifecycle events with background services.
//

import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    var containerProvider: () -> AppContainer? = { nil }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        guard let container = containerProvider() else { return true }
        container.notificationManager.configureNotificationSupport()
        container.backgroundTaskCoordinator.registerBackgroundTasks()
        container.backgroundTaskCoordinator.scheduleProcessingTask()
        container.backgroundTaskCoordinator.scheduleAppRefresh()
        container.notificationManager.registerForRemoteNotifications(application: application)
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        guard let container = containerProvider() else { return }
        container.hrSampleRepository.sceneDidEnterBackground()
        container.backgroundTaskCoordinator.scheduleProcessingTask()
        container.backgroundTaskCoordinator.scheduleAppRefresh()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        containerProvider()?.backgroundTaskCoordinator.cancelAll()
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        containerProvider()?.notificationManager.didRegisterForRemoteNotifications(with: deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        containerProvider()?.notificationManager.didFailToRegisterForRemoteNotifications(error: error)
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let coordinator = containerProvider()?.backgroundTaskCoordinator else {
            completionHandler(.noData)
            return
        }
        coordinator.handleRemoteNotification(userInfo: userInfo, completion: completionHandler)
    }
}
