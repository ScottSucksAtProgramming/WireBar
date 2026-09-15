# Guide: Making Beta Keys

A beta key unlocks WireBar's paid features for one tester until an end date (90 days unless you choose otherwise). You make keys on your Mac and send them to testers. Nothing goes through a server.

Why it works this way: `DESIGN_DECISIONS.md` Q43.

---

## Make a key

1. Open Terminal and go to the project:

   ```bash
   cd ~/programming_projects/wifi-menubar
   ```

2. Run the key maker with the tester's name:

   ```bash
   swift scripts/make-beta-key.swift "Jamie Rivera"
   ```

   For a different length, add the number of days at the end. For example, 30 days:

   ```bash
   swift scripts/make-beta-key.swift "Jamie Rivera" 30
   ```

3. It prints two lines:

   ```
   Beta key for Jamie Rivera, ends December 14, 2026:
   WBETA-SmFtaWUgUml2ZXJhfDE3OTc...
   ```

   The key is the whole second line, starting with `WBETA-`. Copy all of it.

---

## Send it to the tester

Send the key in a private message (text, email, DM). Include these steps:

> 1. Download WireBar from https://github.com/ScottSucksAtProgramming/WireBar/releases/latest and drag it into Applications.
> 2. Open WireBar, click its icon in the menu bar, and open **Settings**.
> 3. Go to the **License** tab.
> 4. Paste your key into **Enter license key** and click **Activate**.
> 5. The plan should now say **Beta**, with **Beta Access Ends** showing your end date.

Updates come through WireBar itself (**Settings → About → Check for Updates**), so testers never need a new key for a new version.

---

## What testers see

| Situation | License tab shows |
|---|---|
| No key yet | Plan: **Free** |
| Key activated | Plan: **Beta**, plus **Beta Access Ends: \<date\>** |
| Key typed wrong or changed | "Invalid license key. Please try again." |
| End date has passed | Plan goes back to **Free**, and "This beta key has expired." stays visible until a new key is entered |

WireBar rechecks the end date every hour, so features lock on the end date even if the app is never restarted.

---

## Common tasks

**Extend a tester.** Make them a new key with more days and send it. There's no way to change an existing key's date.

**Take a key back.** You can't turn off a key remotely. It stops working on its end date. For friends-only testing, keep end dates short.

**Tester switches Macs.** The same key works on any Mac; it isn't tied to one computer.

---

## The signing key: protect it

The key maker signs every beta key with a private file on your Mac:

```
~/.wirebar/beta-signing-key
```

- **Never commit it, share it, or paste it anywhere.** Anyone with this file can make unlimited beta keys. The repo is public, which is why the file lives outside it.
- **Keep your backup current.** If the file is lost, you can't make new keys. Keys you already sent keep working until they end. Making a new signing file would also require an app update, because the app only trusts the current one.
- If you ever run the key maker on a Mac that doesn't have the file, it creates a **new** one and prints "Created signing key". Keys from that new file won't work in the app. Stop and restore your backup instead.

---

## Before the paid launch

Beta keys are temporary. Before selling licenses through LemonSqueezy, remove the beta key code (listed at the end of `DESIGN_DECISIONS.md` Q43), including `scripts/make-beta-key.swift`.
