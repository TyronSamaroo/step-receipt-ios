# CloudKit Household Competition Schema

Container: `iCloud.com.tyronsamaroo.stepreceipt`

Deploy these record types in **Development** and **Production** via CloudKit Dashboard before expecting household sync to work on device.

## Public database

### `HouseholdCompetitionBoard`

| Field | Type | Notes |
| --- | --- | --- |
| `groupHash` | String | SHA-256 of normalized invite code |
| `schemaVersion` | Int(64) | Currently `1` |
| `inviteCodeHint` | String | Last 4 characters of invite code |
| `entryNames` | String List | Deterministic `CompetitionEntry` record names |
| `privacyBoundary` | String | `competition-aggregates-only` |
| `updatedAt` | Date/Time | Board update timestamp |

Record name pattern: `competition-board-{groupHash}`

### `CompetitionEntry`

| Field | Type | Notes |
| --- | --- | --- |
| `groupHash` | String | Board group hash |
| `schemaVersion` | Int(64) | Currently `1` |
| `competitorID` | String | UUID string |
| `displayName` | String | Board name on that phone |
| `initials` | String | Optional avatar initials |
| `accentHex` | String | Accent color hex |
| `dayKey` | String | `yyyy-MM-dd` |
| `steps` | Int(64) | Daily step total |
| `distanceMeters` | Double | Daily distance |
| `activeEnergyKilocalories` | Double | Daily active burn |
| `workoutMinutes` | Double | Daily workout minutes |
| `updatedAt` | Date/Time | Last write time |

Record name pattern: `competition-entry-{sha256(groupHash|entryID)}`

## Security roles (public database)

Grant **Authenticated** users:

- Create, Read, Write on `HouseholdCompetitionBoard`
- Create, Read, Write on `CompetitionEntry`

The invite code is the app-level shared secret. Anyone with the code can read/write that board.

## Private database (existing)

- `DailyActivitySummary` for optional private aggregate summary sync (separate from competition board).

## Validation

After deploying schema:

1. Build production bundle `com.tyronsamaroo.stepreceipt` (not `LOCAL_NO_CLOUDKIT`).
2. Run `Tools/validate-household-compete.sh` on each phone.
3. Tyron creates a code and syncs; Tiffany joins the same code and syncs.
4. Both phones should show two members on the Compete leaderboard.
