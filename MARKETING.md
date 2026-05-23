# DoseToData — Marketing Plan

> Goal: drive the first wave of real users to a live, free iOS app, learn what
> resonates, and build a repeatable acquisition loop. Organic-first (low/no
> budget), then layer in paid once we know what converts.

---

## 1. Who we're actually talking to

Three core audiences, in priority order:

1. **The "is this even working?" crowd** — people recently started on an SSRI,
   ADHD stimulant, or mood stabilizer who can't tell if it's helping. *This is
   our sharpest hook: "Know if your meds are actually working."*
2. **Dose-adjusters** — already medicated, changing dose or switching meds,
   want to compare before/after. (The "Tests" feature is built for them.)
3. **Self-quantifiers** — ADHD / anxiety folks who already track mood and want
   something purpose-built for meds.

**Positioning in one line:**
> "Your memory can't tell you if your meds are working. Your data can."

---

## 2. Pre-launch hygiene (do these first — they make every channel work better)

- [ ] **Fill in App Store Connect URLs** — Support URL + Marketing URL are still
      placeholders in `AppStore.md`. Privacy/Terms are hosted; point Support at
      `docs/support.html` (or an email link).
- [ ] **Screenshots that sell the outcome**, not the UI — lead with the
      "meds vs. no-meds trend" chart and the Test comparison. Caption each.
- [ ] **App Preview video (15–30s)** — daily check-in → trend appears → "now you
      know." Apple weights this heavily in conversion.
- [ ] **ASO pass** — current keywords are solid. Add long-tail in the subtitle
      experiments later (e.g. "Is my antidepressant working").
- [ ] **In-app review prompt** — trigger after a user logs ~7 check-ins (a
      genuine "aha" moment), never on first launch. Ratings drive ranking.
- [ ] **Set up a simple landing page** — reuse the GitHub Pages site
      (ducks123.github.io/dosetodata). One screen: hook, 3 screenshots, App
      Store badge. This is where all off-platform traffic lands.

---

## 3. Phase 1 — Organic launch (Weeks 1–4, ~$0)

The strategy: **be genuinely helpful in places where people are already
confused about whether their meds work**, and let the app be the answer.

### Reddit (highest-intent, highest-risk-of-backlash)
Communities are allergic to self-promotion. Rules: contribute value first,
disclose you're the maker, don't spam.
- Target subs: r/ADHD, r/antidepressants, r/lexapro, r/bupropion, r/anxiety,
  r/bipolar, r/QuantifiedSelf.
- Tactic: answer "how do I know if this is working?" threads with real advice
  (track daily, give it 4–6 weeks, compare windows) and *mention* you built a
  tool for exactly this. Or post a genuine "I built this because I couldn't
  tell if my meds worked" story in r/SideProject, r/QuantifiedSelf, r/iosapps.
- Don't blast all subs at once; one thoughtful post/week.

### Short-form video (TikTok + Instagram Reels)
Highest organic reach for $0. Mental-health/ADHD content travels.
- Hooks to test: "POV: you can't remember how you felt before your meds" /
  "I tracked my mood for 30 days on Lexapro, here's the chart" / "How to tell
  if your ADHD meds are actually working."
- 3–5 posts/week, native vertical, show the actual trend chart as the payoff.
- Same clips cross-post to YouTube Shorts.

### Product Hunt + indie communities
- **Product Hunt launch** — schedule a Tue–Thu, line up a few friends to comment
  early. Good for a credibility bump + backlinks, not huge volume.
- Post in r/SideProject, Indie Hackers, Hacker News ("Show HN") with the
  founder story angle.

### Founder story / build-in-public
- A short thread on X / LinkedIn: "I built an app to answer a question my
  doctor couldn't: are these meds doing anything?" People share health stories.
- (Stewart has a social-post voice/skill — use it to draft these.)

---

## 4. Phase 2 — Content & SEO engine (Weeks 4–12, slow burn)

People Google these questions constantly. Own the answers.
- Blog posts on the landing site targeting:
  - "How long does it take for Lexapro/Wellbutrin/Adderall to work?"
  - "How to tell if your antidepressant is working"
  - "Tracking mood while starting a new medication"
- Each post ends with a natural CTA to the app. This compounds for months.
- Cross-post condensed versions to Medium / a Substack for reach.

---

## 5. Phase 3 — Paid + partnerships (only after organic shows what converts)

- **Apple Search Ads** — start tiny ($10–20/day) on exact-match brand-adjacent
  keywords (e.g. "mood tracker", "pill reminder", competitor names). ASA is the
  cleanest paid channel for iOS because intent is already there.
- **Micro-influencers** — ADHD/mental-health creators (10k–100k). Gift access,
  ask for an honest "I tried this" post. Cheaper and more credible than big names.
- **Therapist / psychiatrist outreach** — a one-pager they can hand to patients
  starting meds ("track this for me between visits"). Long game, high trust.

---

## 6. Measurement — what to actually watch

| Metric | Where | Why |
|---|---|---|
| App Store impressions → page views → downloads (conversion %) | App Store Connect | Tells you if ASO/screenshots work |
| Downloads by source | App Store Connect (web referrer, App Referrer) | Which channel actually drives installs |
| D1 / D7 retention | RevenueCat / analytics | Health app retention is the real signal |
| Check-ins per user (week 1) | In-app analytics | Proxy for the "aha" moment |
| Trial start → paid conversion | RevenueCat | Whether the funnel monetizes |
| Ratings count + average | App Store Connect | Drives ranking + social proof |

> Rule of thumb: don't spend a dollar on paid until D7 retention and trial
> conversion look healthy organically. Otherwise you're paying to fill a leaky
> bucket.

---

## 7. First two weeks — concrete checklist

- [ ] Fill Support + Marketing URLs in App Store Connect
- [ ] Rewrite screenshots to lead with the trend/Test charts + add preview video
- [ ] Stand up the one-page landing site with App Store badge
- [ ] Record 5 short-form videos; post 1/day across TikTok + Reels + Shorts
- [ ] Write the founder-story post (X/LinkedIn) + one r/QuantifiedSelf post
- [ ] Schedule the Product Hunt launch
- [ ] Wire the in-app review prompt to fire after ~7 check-ins
- [ ] Set up download-by-source tracking so we know what's working by week 2

---

*Caveat for all messaging: DoseToData is not a medical device and gives no
medical advice. Keep claims to "track, see patterns, talk to your doctor" —
never "this will improve your treatment." Stay clear of Apple's and the FTC's
health-claims lines.*
