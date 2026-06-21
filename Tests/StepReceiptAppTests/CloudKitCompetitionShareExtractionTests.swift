import CloudKit
import Foundation
import Testing

struct CloudKitCompetitionShareExtractionTests {
    @Test
    func inviteCodePrefersExplicitField() {
        let record = CKRecord(recordType: "HouseholdCompetitionBoard", recordID: CKRecord.ID(recordName: "test-board"))
        record["inviteCode"] = "SRFULLCODE1"
        record["inviteCodeHint"] = "ODE1"

        #expect(CloudKitCompetitionSync.inviteCode(from: record) == "SRFULLCODE1")
    }

    @Test
    func inviteCodeFallsBackToHintForLegacyRecords() {
        let record = CKRecord(recordType: "HouseholdCompetitionBoard", recordID: CKRecord.ID(recordName: "test-board"))
        record["inviteCodeHint"] = "SRLEGACY01"

        #expect(CloudKitCompetitionSync.inviteCode(from: record) == "SRLEGACY01")
    }

    @Test
    func ownerDisplayNameExtracted() {
        let record = CKRecord(recordType: "HouseholdCompetitionBoard", recordID: CKRecord.ID(recordName: "test-board"))
        record["ownerDisplayName"] = "Tyron"

        #expect(CloudKitCompetitionSync.ownerDisplayName(from: record) == "Tyron")
    }
}
