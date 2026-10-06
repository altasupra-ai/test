---
name: fb-post-responses
description: Watch Jason's Facebook group posts for new comments, DM each genuine commenter, then reply under their comment (e.g. "just sent you a message"). Works across two Facebook identities, either by switching profiles in one Chrome window or by driving two Chrome windows (one per Chrome profile) side by side. Use when Jason says "check my posts", "respond to comments", "DM the people who commented", "/fb-responses", or asks to run the post-response loop.
---

# Facebook Post Responses (comment → DM → reply)

You are running Jason's **post-response** system, the companion to `/fb-groups`
(joining) and `/fb-comments` (drafting comments). Same spreadsheet
(**Facebook group management**), same helper CLI
(`C:\Users\Jason\Claude Projects\FacebookGroups\` → `node sheet.js ...`).

The job, for every **new** comment left on one of our posts:

1. **DM** the commenter with a short, personal message.
2. **Reply under their comment** so they (and everyone reading) know to check
   their messages.
3. **Log it** so the same person is never messaged twice.

DM first, reply second, always. The public reply says "sent you a message", so
it must be true when it goes up.

Arguments:

| Call | Does |
|---|---|
| `/fb-responses` | Scan → draft → show Jason the batch → send on his OK (default) |
| `/fb-responses scan` | Scan and draft only. Nothing is sent. |
| `/fb-responses send` | Send the drafts already approved in the sheet |
| `/fb-responses auto` | Scan and send without a per-batch OK (pacing caps still apply) |
| `/fb-responses status` | Report the queue and the ledger, touch nothing on Facebook |
| `... --profile=<name>` | Limit the run to one profile from `profiles.json` |

For a recurring watch, run it under `/loop` (e.g. `/loop 30m /fb-responses`).
Don't go below 20 minutes; see **Pacing**.

---

## THE HARD RULES

1. **Only reply to comments on our own posts.** Never DM someone who didn't
   comment on one of our posts, and never comment on anyone else's post from
   this skill.
2. **One person, one DM, ever (per post).** Check the ledger before every
   send. If the ledger write fails, stop the run; don't keep sending blind.
3. **Prove which identity you're driving before every send.** See
   **Identity check**. A DM from the wrong profile can't be undone.
4. **Hard stop** on any captcha, checkpoint, "You're temporarily blocked",
   "We limit how often...", "This feature is unavailable", or a login page.
   Stop the whole run (both profiles) and tell Jason. Don't retry, don't
   switch profiles to get around it.
5. **No pitch in the public reply.** Prices, links, and "DM me for a deal"
   belong in the DM. The public reply is one friendly line.
6. **Honesty rule (same as `/fb-comments`).** Jason runs Nexis Connect
   (marketing and websites for home-service businesses). He's not a
   tradesperson. Never claim trade experience.

---

## Profiles: two identities, two ways to run them

Config lives in `profiles.json` next to this file (copy
`profiles.example.json`). Each entry is one Facebook identity:

```json
{
  "mode": "two-windows",
  "profiles": [
    {
      "name": "jason",
      "facebook_display_name": "Jason ...",
      "switch_method": "chrome-profile",
      "chrome_profile_directory": "Default",
      "roles": ["dm", "reply"]
    },
    {
      "name": "second",
      "facebook_display_name": "Second Account Name",
      "switch_method": "chrome-profile",
      "chrome_profile_directory": "Profile 1",
      "roles": ["dm", "reply"]
    }
  ]
}
```

- `roles` decides who does what. By default each profile watches **its own**
  posts and answers its own commenters. If Jason wants one identity to DM and
  the other to post the public reply, set `"roles": ["dm"]` on one and
  `["reply"]` on the other. The skill then follows that split.
- `facebook_display_name` is what the **Identity check** compares against.

### Mode A: `"mode": "switch"` (one Chrome window)

Use this when both identities live under the **same Facebook login**, e.g.
Jason's personal profile and a Page profile he manages.

- `switch_method: "facebook-switcher"`: click the profile picture (top right)
  → **See all profiles** / **Switch to <name>** → pick the profile. Wait for
  the page to reload, then run the Identity check.
- Do all of profile 1's work, switch once, then do all of profile 2's work.
  Don't flip back and forth per comment: every switch is a reload and a
  signal.
- Page profiles can't DM people who haven't messaged the Page first in some
  cases. If the Message button is missing or greyed out, see **When the DM
  can't go through**.

### Mode B: `"mode": "two-windows"` (two Chrome profiles side by side)

Use this when the identities are **different Facebook logins**. Each one needs
its own Chrome profile, because Facebook keeps one login per browser profile.

Setup (once, by Jason):

1. Create the second Chrome profile, log into the second Facebook account in
   it, and install and sign in to the **Claude in Chrome** extension in that
   profile too.
2. Launch both windows with `launch-two-profiles.ps1` (next to this file). It
   opens each profile with `--disable-features=CalculateNativeWinOcclusion` so
   that a window behind another one still loads the feed (see **Prerequisites**).
3. Put the windows side by side or on two monitors.

During a run:

- Claude in Chrome drives **one browser connection at a time**. If the
  toolset has a browser switch/select tool (e.g. `switch_browser`), use it to
  move between the two windows. If it doesn't, finish profile 1, then ask Jason
  to run `/chrome` and pick the other browser, then continue with profile 2.
- After **every** switch, run the Identity check. Don't trust that the switch
  worked.
- Same batching rule as Mode A: all of one profile's work, then all of the
  other's.

### Identity check (before any send, after any switch)

```
javascript_tool: (() => document.visibilityState)()
```
must return `visible`. Then confirm the logged-in identity with a text read
(no screenshot): open `https://www.facebook.com/me`, `get_page_text`, and check
the page's profile name matches `facebook_display_name`. If it doesn't match,
stop and tell Jason which identity you actually see.

---

## Prerequisites (learned the hard way in `/fb-comments`)

- **The window must be visible or nothing loads.** Facebook stops lazy-loading
  when `document.visibilityState === "hidden"` (minimised or fully covered on
  Windows). Launch Chrome with
  `--disable-features=CalculateNativeWinOcclusion` (Chrome fully closed first),
  or keep both windows uncovered for the whole run.
- **Real interactions only.** Facebook ignores synthetic `dispatchEvent`
  clicks and hovers in lots of places. Click, hover, and type with real
  `computer` actions.
- **Feeds and comment lists are virtualised.** Capture a comment's details
  when you first see it, not after scrolling away.

---

## Step 1: Find new comments

Work per profile, and only across that profile's posts.

**Source 1: notifications (cheapest).** Open
`https://www.facebook.com/notifications` and read it with `get_page_text`.
Keep entries like "<Name> commented on your post in <Group>" and "<Name>
replied to ..." on our posts. Each one links straight to the comment
(`...?comment_id=...`). Grab those hrefs with a DOM read:

```
javascript_tool: (() => JSON.stringify([...document.querySelectorAll('a[href*="comment_id"]')]
  .map(a => (a.getAttribute("href")||"").split("&__")[0])))()
```

**Source 2: known post URLs (catches what notifications miss).** For every
row in **Outreach Tracker** with a `Post URL` (column P) that belongs to this
profile, open the post. Outreach Tracker has no "posted as" column yet, so
until Jason adds one, treat every Post URL as belonging to the first profile in
`profiles.json`. On each post, expand "View more comments" / "Most relevant → All
comments", and read the comments as text.

For each comment, collect:

- commenter **name** and **profile URL** (the `href` on their name)
- **comment text**
- **comment permalink** (post URL + `comment_id`)
- group name and post URL
- whether it's a top-level comment or already a reply in a thread

**Then drop anything already in the ledger** (match on comment permalink, and
also on commenter profile URL + post URL, so an edited or second comment from
the same person doesn't trigger a second DM).

Screenshot discipline is the same as `/fb-comments`: read with
`get_page_text` / DOM reads. Screenshot only to find coordinates for a click,
and at most one per post.

---

## Step 2: Decide who gets a response

Classify each new comment:

| Comment | Action |
|---|---|
| Asks for info, price, "interested", "me", "PM me", "how does this work" | **DM + reply** |
| A real question about the post | **DM + reply** (answer briefly in the DM) |
| Tags a friend ("@Mike you need this") | **Reply only**, thank them. DM the tagged person **only** if they comment themselves |
| General praise / emoji only | **Reply only**, one short line. No DM |
| Our own profile's comments, the other profile's comments | Skip |
| Spam, scams, link drops, bots | Skip, note it |
| Negative, angry, or argumentative | Skip, flag to Jason. Never argue in public |
| Group admin / moderator | Skip, flag to Jason |

When in doubt, flag it rather than send.

---

## Step 3: Write the DM and the reply

**The DM** (two to four sentences, plain text, no links unless the offer in
the sheet includes one):

- Open with their first name and a specific reference to what they said.
  ("hey Dana, saw your comment asking about the free site...")
- Give the answer or next step from the post's offer (`Offer` column in
  Outreach Tracker for that group).
- End with one easy question so they reply. ("what's the business called?")
- Informal, like a text. No templates that read the same across a batch.
  Vary the openings.
- At most one emoji.

**The public reply** (one line):

- Says they've got a message and sounds human. Rotate the wording, e.g.
  "just sent you a message 👍", "messaged you!", "check your inbox, sent you
  the details", "sent you a PM Dana". Never use the same line twice on one
  post.
- If their message might land in **Message requests** (they're not a friend
  of the sending profile), say so: "sent you a message, might be in your
  message requests". This lifts reply rates a lot.

---

## Step 4: Approval (default mode)

Write every draft to the **Post Responses** tab (create it with
`node sheet.js create-tab "Post Responses"` if missing):

| Column | Value |
|---|---|
| Date Found | `TODAY` |
| Profile | profile `name` from `profiles.json` |
| Group Name | verbatim from Outreach Tracker |
| Post URL | URL only |
| Comment URL | permalink with `comment_id` |
| Commenter | name |
| Commenter Profile | profile URL |
| Comment | the comment text |
| Intent | from Step 2 |
| Draft DM | |
| Draft Reply | |
| Status | blank = drafted, `Approved`, `Sent`, `Replied`, `Skipped`, `Failed` |
| Date Sent | |
| Notes | |

Write them with one `bulk-add` call:

```
node sheet.js --tab="Post Responses" bulk-add <file.json>
```

Show Jason a compact table (commenter, comment, draft DM, draft reply) and
ask: send all, send some, or edit. Only send what he approves. In `auto`
mode, skip the question but still write the rows first, so there's a record
before anything goes out.

---

## Step 5: Send (per comment, in this order)

Run the **Identity check** for the profile whose role is `dm`.

**5a. Send the DM.**

1. Open the commenter's profile URL. Click **Message**. (A profile without a
   Message button: see below.)
2. Wait for the chat box. Click into the message field, type the DM with a
   real `computer` type action, press Enter.
3. **Verify** it sent: read the chat panel text and confirm your message
   appears with no "Couldn't send" / "Not delivered" error.
4. Close the chat box.
5. Update the row: `Status=Sent`, `Date Sent=TODAY`. Append to the ledger
   (see below) **now**, before the public reply.

**5b. Reply under their comment.** Switch to the `reply` profile if it's a
different one (and run the Identity check again).

1. Open the comment permalink. Facebook scrolls to and highlights the comment.
2. Click **Reply** under **that** comment, not under the post, not under a
   neighbouring comment. Confirm the reply box shows "Replying to <Name>"
   (text read) before typing.
3. Type the reply, press Enter.
4. **Verify**: re-read the thread text and confirm the reply is under their
   comment.
5. Update the row: `Status=Replied`.

**Pause between people:** a random 60–180 seconds after each person (both
actions). Never send at a fixed rhythm.

### When the DM can't go through

- No Message button, "You can't message this account", or the send fails:
  don't retry. Post a public reply that invites **them** to message instead
  ("tried to message you but it won't go through, send me a message and I'll
  get you the details"). Mark the row `Failed` with the reason in Notes.
- Post deleted or comments turned off: mark `Skipped`, Notes "post removed".
  Still send the DM if the comment details were captured earlier. That's the
  whole point of catching it.

---

## The ledger (never double-message)

`handled.json` next to this file. One entry per person handled:

```json
{ "comment_url": "...", "commenter_profile": "...", "post_url": "...",
  "profile": "jason", "dm": "sent|failed|none", "reply": "sent|failed|none",
  "at": "2026-10-06T15:04:00" }
```

Read it at the start of every run. Write to it right after each successful
DM, not at the end of the run. If the run dies mid-batch, the next run must
still know who already got a message.

---

## Pacing (account safety)

Both accounts hold group memberships that are worth far more than any single
lead. Behave like a person:

- **Max 10 DMs per profile per hour**, **max 30 per profile per day**. Anything
  over the cap waits for the next run. Say so in the summary.
- Random 60–180 s gap between people. Never a fixed interval.
- Recurring runs no more often than every **20 minutes**. 30 is better.
- Message requests (to non-friends) are the riskiest send on Facebook. If
  Facebook ever shows a warning about messaging people you don't know, that's
  a hard stop.
- Don't run right after a security event on the account (email or password
  change, new login alert). Tell Jason and wait a few days.

---

## Mode: status

Read **Post Responses** and `handled.json`, touch nothing on Facebook. Report:
drafts waiting for approval, sent today per profile (vs. the caps), failed
sends and why, and anything flagged for Jason (negative comments, admins).

## Run summary

Close every run with, per profile:

- comments found / new / skipped (and why)
- DMs sent, replies posted, failures
- anything flagged for Jason
- anything held back by the pacing caps
- the link to the **Post Responses** tab

If the run hit a hard stop, put that first, along with exactly what Facebook
showed.
