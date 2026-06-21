import Foundation
import Testing
#if canImport(StepReceiptCore)
@testable import StepReceiptCore
#endif

struct CompeteJoinDeepLinkTests {
    @Test
    func parseValidJoinURL() throws {
        let url = try #require(URL(string: "stepreceipt://compete/join?code=SRTEST1234"))
        #expect(CompeteJoinDeepLink.inviteCode(from: url) == "SRTEST1234")
    }

    @Test
    func parseJoinURLWithoutPathSegment() throws {
        let url = try #require(URL(string: "stepreceipt://compete?code=SRABCDEF01"))
        #expect(CompeteJoinDeepLink.inviteCode(from: url) == "SRABCDEF01")
    }

    @Test
    func parseNormalizesCode() throws {
        let url = try #require(URL(string: "stepreceipt://compete/join?code=sr-test-12"))
        #expect(CompeteJoinDeepLink.inviteCode(from: url) == "SRTEST12")
    }

    @Test
    func parseRejectsMissingCode() throws {
        let url = try #require(URL(string: "stepreceipt://compete/join"))
        #expect(CompeteJoinDeepLink.inviteCode(from: url) == nil)
    }

    @Test
    func parseRejectsWrongHost() throws {
        let url = try #require(URL(string: "stepreceipt://today/join?code=SRTEST1234"))
        #expect(CompeteJoinDeepLink.inviteCode(from: url) == nil)
    }

    @Test
    func parseRejectsWrongScheme() throws {
        let url = try #require(URL(string: "https://compete/join?code=SRTEST1234"))
        #expect(CompeteJoinDeepLink.inviteCode(from: url) == nil)
    }

    @Test
    func joinURLRoundTrip() throws {
        let url = try #require(CompeteJoinDeepLink.joinURL(for: "SRHOUSEHOLD"))
        #expect(url.absoluteString.contains("stepreceipt://compete/join?code=SRHOUSEHOLD"))
        #expect(CompeteJoinDeepLink.inviteCode(from: url) == "SRHOUSEHOLD")
    }
}

struct CompeteJoinRequestTests {
    @Test
    func replaceConfirmationWhenDifferentBoard() {
        let request = CompeteJoinRequest(inviteCode: "SRNEWCODE1", source: .deepLink)
        #expect(request.requiresReplaceConfirmation(currentInviteCode: "SROOLDCODE", boardEnabled: true))
        #expect(!request.requiresReplaceConfirmation(currentInviteCode: "SRNEWCODE1", boardEnabled: true))
        #expect(!request.requiresReplaceConfirmation(currentInviteCode: "SROOLDCODE", boardEnabled: false))
    }
}
