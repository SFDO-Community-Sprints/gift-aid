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

## Requirements

**NPSP must be installed before this package.** The package declares NPSP as a dependency and the installation will be rejected in an org without it.

## Package Installation Link

The package is currently at **beta** status, which means it can be installed in **scratch orgs and sandboxes only** — not in production or Developer Edition orgs. A released version will follow once the beta has been tested.

Current beta: `04tfj000000XLDlAAO`

- Sandbox: <https://test.salesforce.com/packaging/installPackage.apexp?p0=04tfj000000XLDlAAO>

## Post-Installation Steps

1. Grant your users access to the Gift Aid Declaration object and the Gift Aid fields on Contact and Opportunity. *(A packaged permission set is not yet included — see [Issues](https://github.com/SFDO-Community-Sprints/gift-aid/issues).)*
2. Add the Gift Aid fields to your Contact page layouts / dynamic forms (recommended in a dedicated Gift Aid section).
3. Add the **Gift Aid Declarations** related list to the Contact layout.
4. Add the Gift Aid fields to your Opportunity page layouts.
5. Build the Gift Aid reports you need from the **Opportunities with Gift Aid Contact** report type.

Detailed configuration and the full list of components are on the [wiki](https://github.com/SFDO-Community-Sprints/gift-aid/wiki#dependencies-list-of-components).

## Optional: Public Declaration Form

The public declaration form is a **screen flow**, which is included in the package. The Experience Site that hosts it is **not** packaged — Experience Sites depend on org-specific domain settings and a guest user profile that only exists once the site is created.

To set it up:

1. Enable Digital Experiences and register a domain in your org.
2. Create an Experience Site.
3. Add the packaged **Gift Aid Declaration Form** flow to a page on the site.
4. Grant the site's guest user access to the objects and fields the flow writes to.

A reference configuration retrieved from the demo org is kept in `unpackaged/` for contributors who want to deploy it with the CLI. It is not intended for direct installation.

## Demo

A public Gift Aid Declaration form built with this package: <https://orgfarm-740c648d11-dev-ed.develop.my.site.com/GiftAid> *(demo org — may not always be available)*

# Trailblazer Group or Slack Channel Link (access required)

[#osc-gift-aid-conversations](https://salesforce.enterprise.slack.com/archives/C0BAQKE7AJD) on the Salesforce Open Source Commons Slack.

# How to Contribute

Everyone is welcome — admins, developers, Gift Aid subject-matter experts and end users. There are two ways in, and **most contributors do not need Git, VS Code or the CLI**.

## Build and configure (no tooling required)

Declarative work — flows, fields, reports, page layouts — happens in a **shared sprint org** so that changes stay in one place and can be captured cleanly.

1. Ask in the Slack channel for access to the shared sprint org.
2. Build and test your change there.
3. Post in Slack what you changed, so it can be retrieved and committed to this repository.

Please **don't build in your own org and expect it to be merged** — Salesforce metadata such as Flows cannot be merged between orgs, so parallel copies can't be reconciled.

## Test & give feedback

1. Install the package in a scratch org or sandbox (see Installation above).
2. Try the declaration, eligibility and claim-export processes.
3. Raise bugs, ideas and questions as [GitHub Issues](https://github.com/SFDO-Community-Sprints/gift-aid/issues) or in the Slack channel.

## Contribute metadata or code with Git

### Prerequisites

- [Visual Studio Code](https://code.visualstudio.com/) with the [Salesforce Extension Pack](https://marketplace.visualstudio.com/items?itemName=salesforce.salesforcedx-vscode)
- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`)
- [Git](https://git-scm.com/)
- A Salesforce org with NPSP installed that you can deploy to

### Getting started

```bash
git clone https://github.com/SFDO-Community-Sprints/gift-aid.git
cd gift-aid
sf org login web --alias gift-aid-dev
sf project deploy start --source-dir force-app --target-org gift-aid-dev
```

`--source-dir force-app` matters: it deploys the packaged source only. The `unpackaged/` directory holds metadata that is deliberately excluded from the package and should be deployed separately, if at all.

### Repository layout

| Path | Contents |
| --- | --- |
| `force-app/` | Everything that ships in the package |
| `unpackaged/` | Metadata that cannot or should not be packaged: Experience Site, guest profile, standard object page layouts, saved reports |
| `config/` | Scratch org definition (includes the record types NPSP requires) |
| `sfdx-project.json` | Package definition, version number and NPSP dependencies |

### Workflow

1. Create a branch for your change. Sprint work goes on a branch named for the sprint (e.g. `OSC-London_June_2026`); infrastructure work gets its own branch.
2. Build and test in an org, then retrieve the metadata with `sf project retrieve start`.
3. Open a Pull Request into `main` describing what changed and why. Keep PRs focused on a single change.
4. Work during community sprints is coordinated in the Slack channel — check there before starting on something already in progress.

### Building a package version

Package versions are built from `main` by a project maintainer:

```bash
sf package version create \
  --package "Gift Aid" \
  --definition-file config/project-scratch-def.json \
  --installation-key-bypass \
  --wait 20
```

The `--definition-file` flag is required — the validation org needs the Account, Opportunity and Campaign record types defined there, or the NPSP dependency install fails.

### Conventions

- Keep the package **implementation-agnostic where possible**: avoid hard-coding assumptions beyond the stated NPSP/Opportunity scope.
- Use **permission sets**, not profiles.
- Keep org-specific metadata (Experience Site config, guest profile, standard object page layouts) in `unpackaged/`, never in `force-app/`.
- Keep custom report types trimmed to the fields the package needs. Report types generated in a Developer Edition org list every field on the object, including sample and feature-gated fields that don't exist in most orgs and will break the package build.
- Formula-based eligibility fields are designed to be **admin-customisable**; don't lock logic into automation that admins can't change.

# Project Resources and Documentation

- [Wiki Home](https://github.com/SFDO-Community-Sprints/gift-aid/wiki) — overview, data model, automation, roadmap
- [Sprint notes](https://github.com/SFDO-Community-Sprints/gift-aid/wiki/London-June-2026-Sprint) — what was done at each Community Sprint
- [Issues](https://github.com/SFDO-Community-Sprints/gift-aid/issues) — open work and feedback
- [SFDO Community Sprints](https://sfdo-community-sprints.github.io/docs/sprints/) — about the programme
- [HMRC: Claiming Gift Aid](https://www.gov.uk/claim-gift-aid) — official scheme guidance

# License

[BSD-3-Clause](LICENSE) — free to use, modify and redistribute, including commercially, provided the copyright notice is retained. The full terms are in the [LICENSE](LICENSE) file.