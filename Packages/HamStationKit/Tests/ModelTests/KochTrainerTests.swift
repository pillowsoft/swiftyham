// KochTrainerTests.swift
// HamStationKit — Tests for KochTrainer CW training system.

import XCTest
import Foundation
@testable import HamStationKit

class KochTrainerTests: XCTestCase {

    // MARK: - Koch Order

    func testKochOrderCount() {
        XCTAssertEqual(KochTrainer.kochOrder.count, 40, "Koch order should have 40 characters")
    }

    func testKochOrderHasAllLetters() {
        let letters = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let kochLetters = Set(KochTrainer.kochOrder.filter { $0.isLetter })
        XCTAssertEqual(kochLetters, letters, "Koch order should contain all 26 letters")
    }

    // MARK: - Level & Characters

    func testLevel2HasKandM() async {
        let trainer = KochTrainer(level: 2)
        let chars = await trainer.unlockedCharacters
        XCTAssertEqual(chars, ["K", "M"], "Level 2 should unlock K and M")
    }

    func testNextCharAtLevel2() async {
        let trainer = KochTrainer(level: 2)
        let next = await trainer.nextCharacter
        XCTAssertEqual(next, "R", "Next character after level 2 should be R")
    }

    func testNextCharAtMaxLevel() async {
        let trainer = KochTrainer(level: 40)
        let next = await trainer.nextCharacter
        XCTAssertNil(next, "No next character at max level")
    }

    // MARK: - Session Generation

    func testSessionContainsOnlyUnlocked() async {
        let trainer = KochTrainer(level: 5)
        let session = await trainer.generateSession(groups: 10, groupSize: 5)
        let allowed = Set(await trainer.unlockedCharacters)
        let sessionChars = session.filter { $0 != " " }
        for char in sessionChars {
            XCTAssertTrue(allowed.contains(char),
                    "Session should only contain unlocked characters, found '\(char)'")
        }
    }

    func testSessionGroupStructure() async {
        let trainer = KochTrainer(level: 5)
        let session = await trainer.generateSession(groups: 10, groupSize: 5)
        let groups = session.split(separator: " ")
        XCTAssertEqual(groups.count, 10, "Session should have 10 groups")
        for group in groups {
            XCTAssertEqual(group.count, 5, "Each group should have 5 characters")
        }
    }

    // MARK: - Scoring

    func testPerfectScoreAdvances() async {
        let trainer = KochTrainer(level: 5)
        let result = await trainer.scoreAttempt(expected: "KMRSU", actual: "KMRSU")
        XCTAssertEqual(result.accuracy, 1.0, "Perfect match should be 100%")
        XCTAssertTrue(result.shouldAdvance, "Perfect score should allow advancement")
        XCTAssertTrue(result.errors.isEmpty, "No errors expected")
    }

    func testEightyPercentDoesNotAdvance() async {
        let trainer = KochTrainer(level: 5)
        let result = await trainer.scoreAttempt(expected: "KMRSU", actual: "KMRSX")
        XCTAssertTrue(abs(result.accuracy - 0.8) < 0.01, "4/5 correct should be 80%")
        XCTAssertFalse(result.shouldAdvance, "80% should not allow advancement")
    }

    func testEmptyActualZeroAccuracy() async {
        let trainer = KochTrainer(level: 5)
        let result = await trainer.scoreAttempt(expected: "KMRSU", actual: "")
        XCTAssertEqual(result.accuracy, 0.0, "Empty response should be 0%")
        XCTAssertFalse(result.shouldAdvance)
    }

    func testScoringIgnoresSpaces() async {
        let trainer = KochTrainer(level: 5)
        let result = await trainer.scoreAttempt(expected: "KMR SU", actual: "KMRSU")
        XCTAssertEqual(result.accuracy, 1.0, "Spaces should be ignored in scoring")
    }

    // MARK: - Advancement

    func testAdvanceIncrementsLevel() async {
        let trainer = KochTrainer(level: 5)
        let result = await trainer.scoreAttempt(expected: "KMRSU", actual: "KMRSU")
        await trainer.advanceIfReady(result: result)
        let level = await trainer.currentLevel
        XCTAssertEqual(level, 6, "Level should increment from 5 to 6")
    }

    func testNoAdvanceWhenNotReady() async {
        let trainer = KochTrainer(level: 5)
        let result = await trainer.scoreAttempt(expected: "KMRSU", actual: "KXXXX")
        await trainer.advanceIfReady(result: result)
        let level = await trainer.currentLevel
        XCTAssertEqual(level, 5, "Level should remain 5")
    }

    func testCannotAdvanceBeyondMax() async {
        let trainer = KochTrainer(level: 40)
        let result = SessionResult(
            totalCharacters: 10,
            correctCharacters: 10,
            accuracy: 1.0,
            errors: [],
            shouldAdvance: true
        )
        await trainer.advanceIfReady(result: result)
        let level = await trainer.currentLevel
        XCTAssertEqual(level, 40, "Level should not exceed 40")
    }

    // MARK: - Practice Modes

    func testCallsignPracticeValid() async {
        let trainer = KochTrainer()
        let callsigns = await trainer.generateCallsignPractice(count: 10)
        XCTAssertEqual(callsigns.count, 10, "Should generate 10 callsigns")
        for call in callsigns {
            XCTAssertTrue(call.count >= 4 && call.count <= 7,
                    "Callsign '\(call)' should be 4-7 characters")
            XCTAssertTrue(call.contains(where: { $0.isNumber }),
                    "Callsign '\(call)' should contain a digit")
            XCTAssertTrue(call.contains(where: { $0.isLetter }),
                    "Callsign '\(call)' should contain letters")
        }
    }

    func testQsoPracticeRecognizable() async {
        let trainer = KochTrainer()
        let qso = await trainer.generateQSOPractice()
        XCTAssertTrue(qso.contains("DE"), "QSO should contain 'DE'")
        XCTAssertTrue(qso.contains("RST"), "QSO should contain 'RST'")
        XCTAssertTrue(qso.contains("73"), "QSO should contain '73'")
        XCTAssertTrue(qso.contains("K") || qso.contains("SK"),
                "QSO should contain K or SK prosign")
    }

    private typealias SessionResult = KochTrainer.SessionResult
}
