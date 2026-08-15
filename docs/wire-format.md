# Firestore wire format: bottle & diaper_change

Verified against the real `baby-daybook-app` Firestore project by pulling raw
documents (via the Firestore REST API, bypassing the SDK's JSON decoding)
for records the Android app itself created — not records written by this
SDK or CLI. Path shape: `babyData/babyUid_<BABY>/dailyActions/<uid>`.

Method: `baby-daybook activities list <BABY_UID> --output json` was used to
find candidate `bottle` and `diaper_change` docs, then each doc's `uid` was
fetched directly from
`https://firestore.googleapis.com/v1/projects/baby-daybook-app/databases/(default)/documents/babyData/babyUid_<BABY>/dailyActions/<uid>`
with a bearer ID token, so the response shows Firestore's native
`{ typeUrl: value }` wire encoding instead of the SDK's decoded plain JSON
(`FirestoreClient.decodeValue` in `baby-daybook-sdk/src/firestore.ts`
collapses `integerValue` and `doubleValue` into the same JS `number`, which
is exactly the ambiguity this doc resolves).

Sample size: 1036 `bottle` and 400 `diaper_change` records for one baby
profile. Field presence was 100% consistent within each type across the
whole sample (no optional-field variance observed for quick-add entries).

This corpus establishes the native Firestore primitive types. Production
Garmin writes use the SDK's shared revision-4 activity builder, which emits
the complete canonical record shape while preserving these wire types.

## (a) `volume` wire type on `bottle`

Always `doubleValue`, even when the value is a whole number.

Confirmed with two samples:
- `volume: 147.86764782055937` → `{"doubleValue": 147.86764782055937}`
- `volume: 30` → `{"doubleValue": 30}` (not `integerValue`)

The SDK's generic `encodeValue()` picks a numeric wire type from
`Number.isInteger(value)`:

```ts
return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
```

Native daily-action writes therefore mark `volume` as a double field at the
repository boundary. The SDK, MCP commands, and Garmin relay all encode a
round-number volume such as `30` as `doubleValue: 30`.

## (b) Full field set for a quick-add `diaper_change`

100% consistent across all 400 sampled records:

| field | wire type | notes |
|---|---|---|
| `uid` | `stringValue` | document id, also duplicated as a field |
| `babyUid` | `stringValue` | |
| `userUid` | `stringValue` | creator's Firebase user id |
| `type` | `stringValue` | `"diaper_change"` |
| `startMillis` | `integerValue` | |
| `updatedMillis` | `integerValue` | |
| `rev` | `integerValue` | always `3` across the whole account (1436 records checked) |
| `svt` | `timestampValue` | server-set, see (d) |
| `groupUid` | `stringValue` | **always present, always `""`** for diaper changes in this sample (0/400 had a real group) — the field is written, not omitted |
| `notes` | `stringValue` | present even when empty (`""`); 3/400 had real text |
| `pee` | `integerValue` (`0` or `1`) | **not `booleanValue`** despite `DailyAction.pee` being typed `boolean` in `types.ts` |
| `poo` | `integerValue` (`0` or `1`) | same — integer 0/1, not a Firestore boolean |

`groupUid`, `endMillis`, `duration`, `amountUnit` — answering directly:
- `groupUid`: **yes**, always set, but empty string `""` for a plain
  diaper change (no diaper stays in an activity group).
- `endMillis`: **not set**. Not present in any of the 400 samples.
- `duration`: **not set**. Not present in any of the 400 samples.
- `amountUnit`: **not set**. Not present in any of the 400 samples (this
  field is bottle/food-specific, not diaper-specific, and doesn't appear
  even on bottle records — see below).

No sample had both `pee` and `poo` equal to `0` — the app apparently
always sets at least one of them for a logged change.

### Sample raw diaper_change document (redacted)

```json
{
  "name": "projects/baby-daybook-app/databases/(default)/documents/babyData/babyUid_<BABY_UID>/dailyActions/<DOC_UID>",
  "fields": {
    "notes": { "stringValue": "" },
    "babyUid": { "stringValue": "<BABY_UID>" },
    "type": { "stringValue": "diaper_change" },
    "userUid": { "stringValue": "<USER_UID>" },
    "svt": { "timestampValue": "2024-07-06T10:20:04.172Z" },
    "pee": { "integerValue": "1" },
    "rev": { "integerValue": "3" },
    "updatedMillis": { "integerValue": "1720261203201" },
    "poo": { "integerValue": "0" },
    "groupUid": { "stringValue": "" },
    "startMillis": { "integerValue": "1720261201154" },
    "uid": { "stringValue": "<DOC_UID>" }
  },
  "createTime": "2024-07-06T10:20:04.223285Z",
  "updateTime": "2024-07-06T10:20:04.223285Z"
}
```

## (c) Full field set for a `bottle` record

100% consistent across all 1036 sampled records:

| field | wire type | notes |
|---|---|---|
| `uid` | `stringValue` | |
| `babyUid` | `stringValue` | |
| `userUid` | `stringValue` | |
| `type` | `stringValue` | `"bottle"` |
| `startMillis` | `integerValue` | |
| `updatedMillis` | `integerValue` | |
| `rev` | `integerValue` | always `3` |
| `svt` | `timestampValue` | server-set, see (d) |
| `groupUid` | `stringValue` | non-empty in 1034/1036 (2 exceptions had `""`) — bottle feeds are normally grouped, unlike diaper changes |
| `notes` | `stringValue` | present even when empty; 0/1036 had real text in this sample |
| `volume` | `doubleValue` | always a double, see (a) |

Fields the app does **not** set on quick-add bottle records: `endMillis`,
`duration`, `amountUnit`, `amount`, `pauseMillis`, `leftDuration`,
`rightDuration`, `inProgress`, `side`, `temperature`, `reaction`, `pee`,
`poo`, `hairWash`, `deleted` — none appeared in any of the 1036 samples.
Note `amount`/`amountUnit` are not used for bottles at all; the bottle-
specific quantity field is `volume` (presumably already normalized to ml,
independent of the baby's `convertUnits` display setting — see the 147.87
sample, an odd fractional ml value consistent with an oz→ml conversion of a
round oz amount).

### Sample raw bottle document (redacted)

```json
{
  "name": "projects/baby-daybook-app/databases/(default)/documents/babyData/babyUid_<BABY_UID>/dailyActions/<DOC_UID>",
  "fields": {
    "startMillis": { "integerValue": "1727813700000" },
    "userUid": { "stringValue": "<USER_UID>" },
    "babyUid": { "stringValue": "<BABY_UID>" },
    "rev": { "integerValue": "3" },
    "uid": { "stringValue": "<DOC_UID>" },
    "svt": { "timestampValue": "2024-10-01T20:45:47.184Z" },
    "updatedMillis": { "integerValue": "1727815547111" },
    "notes": { "stringValue": "" },
    "type": { "stringValue": "bottle" },
    "volume": { "doubleValue": 147.86764782055937 },
    "groupUid": { "stringValue": "<GROUP_UID>" }
  },
  "createTime": "2024-10-01T20:45:47.221081Z",
  "updateTime": "2024-10-01T20:45:47.221081Z"
}
```

## (d) Is `svt` set server-side?

**Yes.** In every raw document sampled, `svt` is a `timestampValue` a few
tens of milliseconds *before* the document's own `createTime`/`updateTime`
(e.g. `svt = ...47.184Z` vs `createTime = ...47.221081Z`, a 37ms gap;
similarly 39ms and 51ms gaps in two other samples). That gap is the
signature of a Firestore server-value transform: `REQUEST_TIME` resolves
to when the backend started processing the write, which is slightly
earlier than the transaction's final commit timestamp reflected in
`createTime`/`updateTime` — it can't be a client-supplied value, since a
client can't predict the server's commit time ahead of sending the
request.

This matches every SDK daily-action write path:

```ts
updateTransforms: [{ fieldPath: "svt", setToServerValue: "REQUEST_TIME" }],
```

The Garmin relay uses the identical `updateTransforms` /
`setToServerValue: "REQUEST_TIME"` mechanism for `svt` rather than sending
a client-computed timestamp field. `svt` is excluded from the plain fields
payload in `FirestoreClient.set`, `setMany`, and `createManyIfAbsent`.

## Other compatibility notes

- `rev` is a plain client-written `integerValue`, not a per-record edit
  counter. The sampled corpus contains revision 3; current writes use the
  SDK's canonical revision-4 builder.
- Boolean-shaped fields (`pee`, `poo`, and — from the `Baby` doc —
  `convertUnits`, `isPremature`) are written as `integerValue` `0`/`1`,
  **not** Firestore's native `booleanValue`, even though
  `baby-daybook-sdk/src/types.ts` types some of these fields as
  TypeScript `boolean`. The SDK normalizes native `0`/`1` values to booleans
  at its public boundary and encodes them back to integer flags on writes.
  The Garmin relay uses that same codec.
- `notes` and `groupUid` are always present as `stringValue`, using `""`
  for "no value" rather than omitting the field or using `nullValue`.
