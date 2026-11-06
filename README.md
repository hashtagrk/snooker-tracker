# Snooker Tracker

A scoreboard for three-handed snooker. One HTML file, no build step, no dependencies —
open `index.html` in a browser and start the frame.

![three rails, the active player lit in baize, the seven balls below](docs/board.png)

## Scoring

- **Pot** — tap a ball: red 1, yellow 2, green 3, brown 4, blue 5, pink 6, black 7.
  The red shows how many are left and locks at zero.
- **Foul 4–7** — awards the points and ends the visit.
- **Red off — no score** — takes one red off the table without giving anyone points,
  for a red potted on a foul stroke. It does not end the visit, so that stroke is two
  taps: the foul, then the red off.
- **End visit** — passes to the next player in rotation.
- **Undo** — steps back through every pot, foul, red off and change of visit.
- **New frame** — arms on the first tap, resets on the second. Names and the foul rule stay.

Each player's rail shows their score, the current break while they are at the table,
and their highest break of the frame.

## The foul rule

Three-handed snooker has no single convention for fouls, so it is a switch in the header:

| Setting | Effect |
| --- | --- |
| **Both opponents** (default) | each of the other two players receives the penalty |
| **Next player** | only the player who comes to the table next receives it |

The line under the table always states the rule in force.

## Keyboard

| Key | Action |
| --- | --- |
| `1`–`7` | pot that value |
| `F` then `4`–`7` | foul of that value |
| `R` | red off, no score |
| `Space` | end visit |
| `U` | undo |

## What it is not

It keeps score; it does not referee. It will not enforce red-then-colour order or the
colours-in-sequence endgame, and it has no free-ball or miss handling.

The frame is saved in the browser it is open in, so a refresh mid-frame loses nothing —
but it stays on that one device. This is one scoreboard at the table, not three phones
in sync.

## iPhone app

The same page ships as a native iOS app through [Capacitor](https://capacitorjs.com). In the app the frame is
also saved to native storage (iOS can clear a web view's localStorage), and the fonts are bundled, so it works
offline. `index.html` still opens on its own in a browser with no build step.

You need a Mac with Xcode (free from the App Store) and an Apple ID.

1. `npm install`, then `npm run ios`. This copies the page and fonts into `www/`, syncs them into `ios/`, and opens Xcode.
2. In Xcode, select the **App** target → **Signing & Capabilities**, tick **Automatically manage signing**, and choose your Apple ID as the **Team**.
3. Plug in your iPhone, unlock it, tap **Trust**, and pick it as the run destination at the top of Xcode.
4. On the iPhone, turn on **Settings → Privacy & Security → Developer Mode** (it asks to restart).
5. Press **Run** (⌘R). The first time, approve the developer under **Settings → General → VPN & Device Management**.

With a free Apple ID the app runs for 7 days before it needs reinstalling from Xcode.

After editing `index.html`, run `npm run ios:sync` and press Run again. Icon and splash sources live in
`assets/`; regenerate them with `npm run assets`.
