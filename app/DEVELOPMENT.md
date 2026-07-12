# Development setup

Connect IQ toolchain for building and testing the Baby Daybook watch app
(sideloaded personal app, Fenix 7 family). macOS host.

## SDK

Installed via the Connect IQ SDK Manager (`garmin.connectiq.sdkmanager`),
not Homebrew:

- SDK Manager app data: `~/Library/Application Support/Garmin/ConnectIQ/`
- Active SDK: `~/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0-2026-06-09-92a1605b2/`
  (`bin/version.txt`; satisfies the >= 7.4.3 requirement for sideloads on
  current Fenix firmware)
- Device profiles: `~/Library/Application Support/Garmin/ConnectIQ/Devices/`
  — includes `fenix7`, `fenix7s`, `fenix7x`, and the Pro/no-wifi variants
  (`fenix7pro`, `fenix7spro`, `fenix7xpro`, `fenix7pronowifi`,
  `fenix7xpronowifi`)

`monkeyc` and the simulator (`connectiq`, `monkeydo`) are on `PATH` via
`~/.zshrc`:

```sh
export PATH="/Users/kjopek/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0-2026-06-09-92a1605b2/bin:$PATH"
```

This points at one specific SDK version; when the SDK Manager installs a
newer version, update the path (or symlink a stable `Sdks/current` name)
and re-source `~/.zshrc`. Verify with:

```sh
monkeyc --version
```

## Signing key

Every sideloaded `.prg` must be signed with a self-generated key — no
Garmin developer account needed. Key pair lives in `../keys/` (gitignored,
never commit it):

```sh
openssl genrsa -out keys/developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -nocrypt \
  -in keys/developer_key.pem -out keys/developer_key.der
```

Only `developer_key.der` is used for builds; `developer_key.pem` is the
source key material, kept for regenerating the DER if needed.

## Build

From `app/`, once `monkey.jungle` exists:

```sh
monkeyc -d <deviceId> -f monkey.jungle -o BabyDaybook.prg -y ../keys/developer_key.der
```

`<deviceId>` is one of `fenix7`, `fenix7s`, `fenix7x` (or the Pro variants).
Build a separate `.prg` per device — Connect IQ device binaries are not
interchangeable across profiles.

## Simulator

Launch the simulator, then run a build in it:

```sh
connectiq &                 # starts the device simulator UI
monkeydo BabyDaybook.prg <deviceId>   # loads and runs the built .prg on the running simulator
```

`connectiq` must be running before `monkeydo` will attach.

### Glance launch mode

The simulator defaults complication taps (`Complications.exitTo`) to
glance-mode launch. For testing complication-driven launches, set the
simulator's **Glance Launch Mode** to **Launch in Normal Mode**
(simulator menu, per-app or global setting) so the app opens normally
instead of into its glance.

## Verification performed

Confirmed the toolchain end-to-end by building the SDK's bundled `Analog`
sample for `fenix7`, signed with `keys/developer_key.der`:

```sh
monkeyc -d fenix7 -f monkey.jungle -o Analog.prg -y ../keys/developer_key.der
```

Result: `BUILD SUCCESSFUL`.
