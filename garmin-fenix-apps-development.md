# Garmin Fenix Apps Development

[Open in ChatGPT](https://chatgpt.com/c/6a52bc28-cc98-8331-a42a-d56f9d6f66eb)

## You

Garmin fenix apps how are they made

## ChatGPT

Garmin Fenix apps are built using **Connect IQ**, Garmin's SDK and app platform. They're much closer to embedded apps than Android or iOS apps because the watches have limited CPU, RAM, battery, and storage.

### The language: Monkey C

Garmin created its own language called **Monkey C**. It looks similar to JavaScript or Java:

```monkeyc
class MyApp extends App.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [ new MainView(), new MainDelegate() ];
    }
}
```

It's:
- Object-oriented
- Garbage collected
- Compiled to Garmin bytecode
- Designed to run on all Garmin devices

---

### App architecture

Apps are event-driven.

Typical pieces include:
- **Application** – entry point
- **View** – draws the screen
- **Delegate** – handles button/touch input
- **Background services** (limited)
- **Data fields** (shown during activities)
- **Widgets / Glances**
- **Watch faces**

There are actually several different app types:
- Watch Face
- Widget (Glance)
- Device App
- Data Field
- Audio Content Provider

---

### UI

You draw directly onto a graphics context.

Example:

```monkeyc
function onUpdate(dc) {
    dc.clear();

    dc.drawText(
        dc.getWidth()/2,
        dc.getHeight()/2,
        Graphics.FONT_MEDIUM,
        "Hello",
        Graphics.TEXT_JUSTIFY_CENTER
    );
}
```

There isn't a rich UI toolkit like SwiftUI or React. Most interfaces are manually drawn.

---

### Sensors

You get APIs for:
- GPS
- Heart rate
- Barometer
- Compass
- Accelerometer
- Pulse Ox (on supported models)
- Sleep
- Activities
- Body Battery (limited)
- Weather
- Notifications

Not every sensor is available on every device.

---

### Connectivity

Apps can:
- Connect to the paired phone
- Make HTTPS requests (through the phone)
- Use Bluetooth
- Store local data

Internet access generally goes through Garmin Connect Mobile on the phone (or Wi-Fi/LTE on supported watches).

---

### Development

You use:
- Connect IQ SDK
- Visual Studio Code extension
- Simulator (supports many watch models)

Typical workflow:
1. Write Monkey C
2. Run in simulator
3. Deploy over USB or Wi-Fi
4. Publish to the Connect IQ Store

---

### Performance

Garmin watches are much more constrained than smartphones:
- RAM is often measured in hundreds of KB to a few MB available to apps.
- CPU is relatively slow.
- Battery life is a primary concern.

Apps are expected to be lightweight and efficient.

---

### Can you use other languages?

Officially, **no**. Everything ultimately needs to be written in Monkey C and built with the Connect IQ SDK.

Some developers generate Monkey C from another language or use code generation, but there isn't an officially supported Rust, C++, or Kotlin toolchain.

---

Overall, Connect IQ is a surprisingly capable platform for fitness devices. You can build apps like maps, games, navigation tools, workout assistants, offline data loggers, and even small AI-powered clients (using a phone or cloud backend), but it's intentionally designed with strict limits to preserve battery life and run consistently across the wide range of Garmin watches.

## You

I just need to call apis, build likr a baby daybook mini app. I have javascript sdk

## ChatGPT

I’m checking the current Connect IQ networking and JavaScript interoperability limits so I can map your JS SDK to the simplest Garmin architecture.

That is a **good, simple Garmin app use case**. Build a small **Connect IQ device app** that acts as a thin client for your existing API.

Your JavaScript SDK **cannot run directly on the Fenix**. The watch code must be Monkey C, but you do not need to recreate the entire SDK—just implement the few HTTP calls the watch needs. Garmin exposes `Communications.makeWebRequest()`, which sends asynchronous REST requests and converts JSON responses into Monkey C objects. Internet access normally travels through the paired phone over Bluetooth.

## Recommended architecture

```text
Garmin Fenix app
   |
   | HTTPS JSON
   v
Small Garmin-friendly API
   |
   | Your JavaScript SDK
   v
Existing Baby Daybook backend
```

The Garmin app might only need endpoints like:

```text
GET  /garmin/status
POST /garmin/feed
POST /garmin/diaper
POST /garmin/sleep/start
POST /garmin/sleep/stop
```

Your server can use the existing JavaScript SDK internally:

```javascript
app.post("/garmin/feed", async (req, res) => {
  const result = await babyDaybook.feeding.create({
    childId: req.user.childId,
    type: req.body.type,
    amount: req.body.amount,
    occurredAt: new Date().toISOString()
  });

  res.json({
    ok: true,
    message: "Feeding recorded"
  });
});
```

Then the Garmin code is very small:

```monkeyc
using Toybox.Communications;
using Toybox.System;

function logFeeding() {
    var url = "https://api.example.com/garmin/feed";

    var params = {
        "type" => "bottle",
        "amount" => 120
    };

    var options = {
        :method => Communications.HTTP_REQUEST_METHOD_POST,
        :headers => {
            "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
            "Authorization" => "Bearer " + getToken()
        },
        :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
    };

    Communications.makeWebRequest(
        url,
        params,
        options,
        method(:onResponse)
    );
}

function onResponse(statusCode, data) {
    if (statusCode == 200) {
        System.println("Recorded successfully");
    } else {
        System.println("Request failed: " + statusCode);
    }
}
```

The calls are asynchronous, so the UI should immediately show something like **“Saving…”**, then update to **“Recorded”** or **“Try again.”**

## Authentication

For a private app, I would avoid making the user type credentials on the watch.

Use one of these:

1. **Pairing code**
   - Watch displays `ABCD-1234`
   - User enters it on your website or phone app
   - Watch polls the backend
   - Backend returns a device token

2. **Connect IQ app settings**
   - User configures an API token through Garmin Connect
   - Watch reads it from app properties

3. **OAuth**
   - Garmin supports authenticated web-service flows through its Communications and Authentication APIs, but this is more machinery than you likely need for a personal baby tracker.

Use a revocable, watch-specific token rather than storing the user's normal password.

## Ideal watch UI

Keep it deliberately small:

```text
Baby Daybook

> Feed
  Diaper
  Sleep
  Last event
```

Selecting **Feed**:

```text
Feed

> Bottle 120 ml
  Bottle 150 ml
  Breast left
  Breast right
```

Then provide confirmation:

```text
✓ Bottle 120 ml
  Recorded at 4:32 PM
```

For the first version, I would implement:

- One-click preset actions
- Last feeding/diaper/sleep time
- Undo last action
- Local queue when the phone is disconnected
- Sync indicator

Do not try to recreate the full Baby Daybook interface. The watch should focus on actions that take two or three button presses.

## Reusing your JavaScript SDK

There are three practical options:

**Best:** Put the JavaScript SDK on your backend and expose simplified Garmin endpoints.

**Possible:** Manually port only the SDK's request signing and API calls to Monkey C.

**Usually bad:** Generate Monkey C automatically from the JavaScript SDK. The languages and runtime APIs differ enough that this tends to become more work than maintaining a tiny watch client.

Garmin's current SDK remains Monkey C-based, and the supported APIs depend on both the app type and target watch model.

For this project, the watch portion could realistically remain a small app: a few views, several API calls, token storage, and a minimal offline queue.

## You

I dont want to host server

## ChatGPT

You **do not need to host another server** if your JavaScript SDK ultimately calls a public HTTPS API that the Garmin watch can call directly.

The setup becomes:

```text
Garmin Fenix app
    |
    | HTTPS requests through Garmin Connect on phone
    v
Existing Baby Daybook API
```

Garmin’s `Communications.makeWebRequest()` supports REST/JSON requests directly from a Connect IQ app. The paired phone generally acts as the internet bridge.

The limitation is that your **JavaScript SDK itself cannot run on the watch**. You would inspect what HTTP requests the SDK makes and reproduce just those requests in Monkey C.

For example, if your JavaScript SDK does:

```javascript
client.events.create({
  type: "bottle",
  amount: 120
});
```

and internally sends:

```http
POST https://api.example.com/events
Authorization: Bearer abc123
Content-Type: application/json

{
  "type": "bottle",
  "amount": 120
}
```

the Garmin equivalent would be roughly:

```monkeyc
using Toybox.Communications;

function recordBottle() {
    var url = "https://api.example.com/events";

    var body = {
        "type" => "bottle",
        "amount" => 120
    };

    var options = {
        :method => Communications.HTTP_REQUEST_METHOD_POST,
        :headers => {
            "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
            "Authorization" => "Bearer " + getToken()
        },
        :responseType =>
            Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
    };

    Communications.makeWebRequest(
        url,
        body,
        options,
        method(:onResponse)
    );
}

function onResponse(statusCode, response) {
    if (statusCode >= 200 && statusCode < 300) {
        // Show success
    } else {
        // Show error
    }
}
```

## The real question is authentication

Direct access works well when the API supports one of these:

- A long-lived API token
- OAuth
- An API key tied to your account
- Username/password exchange that returns a token

Garmin supports OAuth flows that redirect through the Garmin Connect mobile app.

For a personal app, the easiest approach is often:

1. Obtain an access token using your normal web or JavaScript tooling.
2. Paste it into the app’s Connect IQ settings.
3. Store it as a password-type setting.
4. Read it from Monkey C and attach it to requests.

Connect IQ settings can be edited through Garmin Connect, Connect IQ Store, or Garmin Express, and password fields are supported.

## Cases where direct calls may not work

You may still need a proxy if the JavaScript SDK:

- Performs complicated cryptographic request signing
- Depends on browser cookies
- Uses an undocumented private API
- Requires a client secret that must not be exposed
- Uses WebSockets rather than ordinary HTTP
- Encrypts request bodies using substantial JavaScript code
- Calls an API that blocks Garmin’s network requests

But if it is essentially a wrapper around ordinary authenticated JSON endpoints, manually porting five or ten methods is likely straightforward.

So the minimal project is:

```text
Monkey C UI
+ direct HTTPS calls
+ token in Garmin app settings
+ optional local retry queue
```

No custom backend and no separate phone application are required.

## You

And what about network, i want something that it queues the calls if no network

## ChatGPT

Yes. You can implement a **persistent offline queue directly on the watch**, without hosting anything.

Garmin does not automatically queue failed `makeWebRequest()` calls. Your app should:

1. Save the action locally before attempting the request.
2. Try sending it.
3. Remove it only after a successful response.
4. Retry pending actions when the app opens and during supported background runs.

Connect IQ provides persistent application storage through `Toybox.Application.Storage`; it survives the app closing and the watch restarting.

## Queue model

Store compact action objects:

```monkeyc
[
    {
        "id" => "1720738212-1",
        "type" => "bottle",
        "amount" => 120,
        "occurredAt" => 1720738212,
        "attempts" => 0
    },
    {
        "id" => "1720738500-2",
        "type" => "diaper",
        "kind" => "wet",
        "occurredAt" => 1720738500,
        "attempts" => 1
    }
]
```

The important field is a unique `id`. Your target API should use it as an idempotency key, so a timeout does not accidentally record the same feeding twice.

## Basic implementation

```monkeyc
using Toybox.Application;
using Toybox.Communications;
using Toybox.System;
using Toybox.Time;

class SyncQueue {

    private var _sending = false;

    function loadQueue() {
        var queue = Application.Storage.getValue("syncQueue");

        if (queue == null) {
            return [];
        }

        return queue;
    }

    function saveQueue(queue) {
        Application.Storage.setValue("syncQueue", queue);
    }

    function enqueue(action) {
        var queue = loadQueue();

        action["id"] =
            Time.now().value().toString() + "-" + queue.size().toString();

        action["occurredAt"] = Time.now().value();
        action["attempts"] = 0;

        queue.add(action);
        saveQueue(queue);

        flush();
    }

    function flush() {
        if (_sending) {
            return;
        }

        var queue = loadQueue();

        if (queue.size() == 0) {
            return;
        }

        _sending = true;
        send(queue[0]);
    }

    function send(action) {
        var url = "https://existing-api.example.com/events";

        var headers = {
            "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
            "Authorization" => "Bearer " + getToken(),
            "Idempotency-Key" => action["id"]
        };

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => headers,
            :responseType =>
                Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        Communications.makeWebRequest(
            url,
            action,
            options,
            method(:onResponse)
        );
    }

    function onResponse(statusCode, response) {
        var queue = loadQueue();

        if (queue.size() == 0) {
            _sending = false;
            return;
        }

        if (statusCode >= 200 && statusCode < 300) {
            queue.remove(0);
        } else {
            queue[0]["attempts"] = queue[0]["attempts"] + 1;
        }

        saveQueue(queue);
        _sending = false;

        // Continue only after success. Avoid hammering a failed connection.
        if (statusCode >= 200 && statusCode < 300) {
            flush();
        }
    }

    function getToken() {
        return Application.Storage.getValue("token");
    }
}
```

The HTTP request is asynchronous and normally travels through Garmin Connect Mobile on the paired phone.

## Recording should feel instant

When the user taps **Bottle 120 ml**:

```monkeyc
queue.enqueue({
    "type" => "bottle",
    "amount" => 120
});
```

Immediately show:

```text
✓ Bottle recorded
Waiting to sync
```

Do not make the user wait for the HTTP response. The local queue is the immediate source of truth until synchronization succeeds.

A small status indicator is useful:

```text
✓ Synced

or

↻ 3 pending
```

## When to retry

Retry:

- Immediately after adding an action
- Whenever the app opens
- When the user presses “Sync now”
- During a periodic background event, where supported
- After another request succeeds

Connect IQ supports scheduled background events, but background execution is constrained, receives a smaller memory pool, and may be terminated for higher-priority work. It should be treated as opportunistic synchronization rather than guaranteed immediate delivery.

A practical retry policy:

```text
First failure: stop
Next app opening: retry
Background event: retry
Manual sync: retry
```

You generally do not need aggressive exponential retry loops on the watch. They waste battery and will not restore a missing phone connection.

## Important edge cases

**Timeout after the server accepted the request**

The watch may see a failure even though the API saved the event. This is why idempotency is essential.

**Permanent errors**

Handle `400`, `401`, and `403` differently from temporary connectivity failures:

```text
400 → mark item invalid and show it
401/403 → stop queue and request login/token update
429/500/503/no connection → leave queued and retry later
```

**Queue size**

Keep actions compact and impose a limit, perhaps 50–200 entries. For a baby tracker, that represents days or weeks of offline use.

**Chronological order**

Send oldest first. Store the actual event timestamp at the moment the parent presses the button; do not use the later synchronization time.

## Best design for this app

```text
User records event
       ↓
Persist locally
       ↓
Show success instantly
       ↓
Attempt HTTPS request
       ↓
Success: delete local queue item
Failure: retain and retry later
```

That gives you a fully usable offline-first mini Baby Daybook app without another server, provided the existing API accepts direct HTTPS calls from the Garmin client.

## You

Does garmin have some dev environemtn that can be utilized by agents?

## ChatGPT

Yes, to a degree. Garmin's developer tooling is actually fairly automation-friendly, though not as polished as Android or web development.

The main pieces are:

- **Connect IQ SDK** — command-line tools for building and packaging apps.
- **Connect IQ Simulator** — can be launched from the command line with a chosen device profile (e.g. Fenix 8, Epix, Forerunner). You can install an app into it automatically.
- **VS Code extension** — mostly a convenience layer over the SDK.

For an AI agent, a workflow like this is realistic:

```text
Edit Monkey C source
      ↓
Build via CLI
      ↓
Launch simulator
      ↓
Install app
      ↓
Read build errors
      ↓
Repeat
```

An agent can easily automate:
- Writing Monkey C
- Running builds
- Fixing compiler errors
- Switching simulated watch models
- Packaging `.prg` files
- Running unit-test-like logic (where possible)

The weak point is **UI testing**.

Unlike Playwright or Xcode's XCTest, Garmin doesn't provide a rich automation API for driving button presses and inspecting the screen. The simulator is primarily meant for a human developer. An agent can still:
- Start the simulator
- Capture screenshots
- Potentially simulate some input through supported mechanisms or external OS automation

…but it's not as seamless as browser automation.

For an app like your Baby Daybook client, that's probably fine because most of the complexity is:
- Drawing a few screens
- Making HTTP requests
- Managing the offline queue

An agent can generate and iterate on that code very effectively.

I would say Garmin's tooling is roughly:
- **Build automation:** 9/10
- **Simulator automation:** 7/10
- **End-to-end UI automation:** 4/10

So it's quite feasible to build an AI-assisted development loop, just don't expect the simulator to be as scriptable as a web browser.

## You

How would the ui look? It should be pretty simple, but easily qccessible

## ChatGPT

For a Garmin Fenix, I'd lean into what the hardware is best at: **few clicks, big targets, no typing, and muscle memory**. The user should be able to record an event in 2–3 button presses without looking for long.

## Home screen

```
🐣 Baby

Feed
Diaper
Sleep
Timeline
Sync (2)
```

`Sync (2)` only appears if there are pending items.

---

## Feed

```
Feed

🍼 Bottle
🤱 Breast
🥣 Solid Food
💧 Water
```

Selecting **Bottle** goes directly to common amounts:

```
Bottle

120 ml
150 ml
180 ml
Custom...
```

Pressing `120 ml` immediately records it.

```
✓ Bottle
120 ml

4:37 PM
Synced ✓
```

or

```
✓ Saved

Waiting for phone
```

---

## Diaper

```
Diaper

💧 Wet
💩 Dirty
💧💩 Both
```

One button press after entering the menu.

---

## Sleep

```
Sleep

▶ Start sleep
```

When sleeping:

```
Sleeping...

Started
7:42 PM

■ End sleep
```

---

## Timeline

Instead of a full history:

```
Last events

4:37 Bottle
3:02 Wet
1:15 Sleep end
11:00 Bottle
```

Selecting one could offer:

```
Undo
```

for the last minute or two.

---

## Long-press shortcuts

This is where Garmin shines.

If Garmin allows remapping your app to a hotkey, pressing the hotkey could immediately show:

```
Quick Add

Bottle
Wet
Dirty
Sleep
```

Two button presses and you're done.

---

## Offline indicator

Tiny icon in the corner.

```
✓ Online

or

↻ 3
```

Meaning 3 items waiting to sync.

---

## Optional complications (Glance)

A Glance could show:

```
Baby

Last feed
2h 18m

Last diaper
45m
```

Tapping it opens the app.

---

## Watch Face data field

If you eventually build a watch face:

```
🍼 2h18m
💩 45m
😴 6h12m
```

That gives useful information without opening the app.

## What I'd avoid

Don't try to reproduce the phone app:
- No calendars
- No charts
- No editing old entries
- No settings menus
- No searching

The watch should optimize for **capture**, not management.

---

For a Fenix with physical buttons, I would optimize for a flow like this:

```
Hotkey
↓
Feed
↓
120 ml
↓
✓ Done
```

That's three button presses and about two seconds, which is likely faster than unlocking a phone and opening the app.

## You

I want only actions, nothing else. And only 2 diaper and bottle

## ChatGPT

If it's **actions only**, I'd make it even more opinionated. Think of it as a "baby remote control" rather than an app.

## Option 1: Four actions (my favorite)

```
Baby

🍼 Bottle
💧 Wet
💩 Dirty
😴 Sleep
```

Selecting one immediately performs the action.

For Bottle:

```
Bottle?

Press START
```

Then:

```
✓ Bottle
Saved
```

No submenus.

---

## Option 2: Giant buttons

```
+------------------+
|                  |
|      🍼          |
|     Bottle       |
|                  |
+------------------+

Next: Wet
```

Use Up/Down to cycle through:
- Bottle
- Wet
- Dirty
- Sleep

Press **Start** to execute.

This is probably the fastest interface on a Fenix.

---

## Option 3: Radial menu

If you want it to feel more modern:

```
        🍼

💧              💩

        😴
```

Select with the directional buttons.

---

## Sleep

Sleep is the only stateful action.

When not sleeping:

```
😴 Start Sleep
```

When sleeping:

```
😴 End Sleep

Started 2h14m ago
```

---

## Confirmation

Don't require confirmation before recording. Instead, show a success screen for about a second:

```
✓ Wet diaper
```

or

```
✓ Bottle
```

If offline:

```
✓ Bottle

Queued
```

---

## Long-press undo

After saving:

```
✓ Bottle

Hold BACK to undo
```

Give the user 5–10 seconds to undo if they tapped accidentally.

---

## Physical button mapping

On a Fenix with five buttons:

- **Up/Down** → Move between actions
- **Start** → Execute
- **Back** → Cancel or undo recent action

That lets you record almost everything with two presses:

```
Open app
↓
Start
```

or

```
Open app
↓
Down
↓
Start
```

No scrolling through lists or filling out forms.

For your use case, I think **Bottle, Wet, Dirty, and Sleep** is exactly the right scope. The phone remains the place for everything else (history, edits, notes, amounts, trends), while the watch is optimized for capturing events in the fewest possible interactions.

## You

And the entry point?

## ChatGPT

The entry point is actually the most important UX decision. On a Fenix, people don't want to navigate menus.

Here are the options I'd consider, in order.

### 1. Hotkey launch (best)

Garmin lets users assign an app to a hotkey (for example, long-press START or LIGHT).

When launched:

```text
🍼 Bottle
💧 Wet
💩 Dirty
😴 Start Sleep
```

Cursor starts on the most common action (Bottle).

Typical flow:

- Long press hotkey
- Press START

Done in about 2 seconds.

---

### 2. Glance (my favorite companion)

The app also exposes a Glance:

```text
👶 Baby

Tap to Add Event
```

Opening it goes directly to the action list above.

---

### 3. Widget + quick actions

Instead of a menu, the first screen is just a vertical list:

```text
▶ 🍼 Bottle
  💧 Wet
  💩 Dirty
  😴 Sleep
```

START executes.

---

### 4. Remember last selection (probably what I'd build)

If 90% of your entries are bottles, reopening the app should remember the previous position.

For example:

```
Yesterday:
Bottle
Bottle
Bottle
Wet
Bottle
Bottle
```

The next launch opens on **Bottle**, so the user usually just:

- Launch
- START

If the last thing was Sleep and it's currently active, open on:

```
😴 End Sleep
```

---

## Bonus: Smart defaults

You can make it feel much smarter with almost no complexity.

If:
- Sleep is active → highlight **End Sleep**
- Last diaper was >3 hours ago → highlight **Wet**
- Otherwise → highlight **Bottle**

The user doesn't need to think.

---

## My ideal flow

```
Hotkey
      ↓
🍼 Bottle
💧 Wet
💩 Dirty
😴 Sleep
      ↓
START
      ↓
✓ Saved
(auto close after ~1 second)
```

The app behaves almost like a hardware button for baby logging rather than a traditional application. That's the experience I'd optimize for on a Fenix.
