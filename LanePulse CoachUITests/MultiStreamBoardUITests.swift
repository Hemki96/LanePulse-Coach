//
//  MultiStreamBoardUITests.swift
//  LanePulse CoachUITests
//
//  Covers layout, interactions and performance for the multi-stream board.
//

import XCTest

@MainActor
final class MultiStreamBoardUITests: XCTestCase {
    private var app: XCUIApplication!
    private let sessionIdentifier = "11111111-2222-3333-4444-555555555555"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["--uitest-multi-stream"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testBoardDisplaysAllMultiStreamTiles() throws {
        openMultiStreamSession()

        let tiles = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "board_tile_"))
        XCTAssertEqual(tiles.count, 4, "Expected four board tiles for seeded athletes")

        let detailPane = app.otherElements["detail_pane"]
        XCTAssertFalse(detailPane.exists)

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "MultiStreamBoard"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSelectingTileShowsDetailPane() throws {
        openMultiStreamSession()

        let tiles = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "board_tile_"))
        let firstTile = tiles.element(boundBy: 0)
        XCTAssertTrue(firstTile.waitForExistence(timeout: 2))
        firstTile.tap()

        let detailPane = app.otherElements["detail_pane"]
        XCTAssertTrue(detailPane.waitForExistence(timeout: 2))
        XCTAssertTrue(detailPane.staticTexts["Athlete 1"].exists)
    }

    func testSwitchingToScoreboardDisplaysCards() throws {
        openMultiStreamSession()

        let picker = app.segmentedControls["view_mode_picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 2))
        picker.buttons["Scoreboard"].tap()

        let scoreboard = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "scoreboard_tile_"))
        XCTAssertGreaterThanOrEqual(scoreboard.count, 4)
    }

    func testMultiStreamPerformanceMetrics() throws {
        let metrics: [XCTMetric] = [
            XCTApplicationLaunchMetric(),
            XCTCPUMetric(),
            XCTMemoryMetric(),
            XCTOSSignpostMetric.applicationTime
        ]

        measure(metrics: metrics) {
            let iterationApp = XCUIApplication()
            iterationApp.launchArguments += ["--uitest-multi-stream"]
            iterationApp.launch()

            let sessionRow = iterationApp.buttons["session_row_\(sessionIdentifier)"]
            XCTAssertTrue(sessionRow.waitForExistence(timeout: 3))
            sessionRow.tap()

            let tiles = iterationApp.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "board_tile_"))
            XCTAssertGreaterThanOrEqual(tiles.count, 4)

            iterationApp.terminate()
        }
    }

    private func openMultiStreamSession() {
        let sessionRow = app.buttons["session_row_\(sessionIdentifier)"]
        XCTAssertTrue(sessionRow.waitForExistence(timeout: 3))
        sessionRow.tap()

        let tiles = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "board_tile_"))
        XCTAssertTrue(tiles.element(boundBy: 0).waitForExistence(timeout: 2))
    }
}
