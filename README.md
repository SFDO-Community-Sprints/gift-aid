# Gift Aid Project

Gift Aid is a UK government scheme that allows registered charities and Community Amateur Sports Clubs (CASCs) to reclaim basic-rate tax on donations made by UK taxpayers. It boosts the value of donations by 25% at no extra cost to the donor.

This project is a free, open-source Salesforce package that lets UK charities manage the Gift Aid lifecycle end-to-end: capture declarations from any source, track donor and donation eligibility, and export HMRC-ready claims.

📖 **Full documentation:** [Project Wiki](https://github.com/SFDO-Community-Sprints/gift-aid/wiki)

# Project Overview

## Vision & Goals

Provide a framework for managing:

- Gift Aid eligibility & declarations of Donors (Contacts);
- Gift Aid eligibility of Donations (Opportunities);
- Submission of Gift Aid claims to HMRC via:
  - CSV report export from Salesforce;
  - CSV import into Salesforce to track submission status.

## Project Vertical

Nonprofit — uses Contact & Opportunity (NPSP).

## Current Scope & Limitations

The initial release targets a single, deliberately simple implementation:

- **NPSP** data model — donations tracked on **Opportunity** (not Payments);
- Compatible with **Recurring Donations**;
- **Person Accounts are not supported**;
- Declarations are stored on a custom **Gift Aid Declaration** object (child of Contact);
- Claims are produced by a report exported as CSV — submission to HMRC is done through your own Gateway.

See [The one-size-fits-all problem](https://github.com/SFDO-Community-Sprints/gift-aid/wiki#the-one-size-fits-all-problem) on the wiki for why, and the [Roadmap](https://github.com/SFDO-Community-Sprints/gift-aid/wiki#roadmap) for the plan towards NPC / Payments / Person Accounts support.

# Installation

## Package Installation Link

*Coming soon — the first unlocked package version is being prepared.*

## Post-Installation Steps

1. Assign the **Gift Aid** permission set to relevant users.
2. Add the Gift Aid fields to your Contact page layouts / dynamic forms (recommended in a dedicated Gift Aid section).
3. Add the **Gift Aid Declarations** related list to the Contact layout.
4. Add the Gift Aid fields to your Opportunity page layouts.

Detailed configuration and the full list of components are on the [wiki](https://github.com/SFDO-Community-Sprints/gift-aid/wiki#dependencies-list-of-components).

## Demo

A public Gift Aid Declaration form built with this package: <https://orgfarm-740c648d11-dev-ed.develop.my.site.com/GiftAid> *(demo org — may not always be available)*

# Trailblazer Group or Slack Channel Link (access required)

[#osc-gift-aid-conversations](https://salesforce.enterprise.slack.com/archives/C0BAQKE7AJD) on the Salesforce Open Source Commons Slack.

# How to Contribute

Everyone is welcome — admins, developers, Gift Aid subject-matter experts and end users.

## Test & give feedback

1. Install the package in a scratch org, Developer Edition or sandbox.
2. Try the declaration, eligibility and claim-export processes.
3. Raise bugs, ideas and questions as [GitHub Issues](https://github.com/SFDO-Community-Sprints/gift-aid/issues) or in the Slack channel.

## Contribute metadata or code

### Prerequisites

- [Visual Studio Code](https://code.visualstudio.com/) with the [Salesforce Extension Pack](https://marketplace.visualstudio.com/items?itemName=salesforce.salesforcedx-vscode)
- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`)
- [Git](https://git-scm.com/)
- A Salesforce org you can deploy to (scratch org or Developer Edition)

### Getting started

```bash
git clone https://github.com/SFDO-Community-Sprints/gift-aid.git
cd gift-aid
sf org login web --alias gift-aid-dev
sf project deploy start --target-org gift-aid-dev
```

### Workflow

1. Fork the repository and create a branch for your change.
2. Build and test in your own org, then retrieve the metadata with `sf project retrieve start`.
3. Open a Pull Request describing what changed and why. Keep PRs focused on a single change.
4. Metadata changes made during community sprints are coordinated in the Slack channel — check there before starting on something already in progress.

### Conventions

- Keep the package **implementation-agnostic where possible**: avoid hard-coding assumptions beyond the stated NPSP/Opportunity scope.
- Use **permission sets**, not profiles.
- Don't commit org-specific metadata (Experience Site config, standard object page layouts, profiles) — these are excluded via `.forceignore`.
- Formula-based eligibility fields are designed to be **admin-customisable**; don't lock logic into automation that admins can't change.

# Project Resources and Documentation

- [Wiki Home](https://github.com/SFDO-Community-Sprints/gift-aid/wiki) — overview, data model, automation, roadmap
- [Sprint notes](https://github.com/SFDO-Community-Sprints/gift-aid/wiki/London-June-2026-Sprint) — what was done at each Community Sprint
- [Issues](https://github.com/SFDO-Community-Sprints/gift-aid/issues) — open work and feedback
- [SFDO Community Sprints](https://sfdo-community-sprints.github.io/docs/sprints/) — about the programme
- [HMRC: Claiming Gift Aid](https://www.gov.uk/claim-gift-aid) — official scheme guidance

# License

[BSD-3-Clause](LICENSE)