
# Exhausted

[![Build FG Extension](https://github.com/rhagelstrom/Exhausted/actions/workflows/create-release.yml/badge.svg)](https://github.com/rhagelstrom/Exhausted/actions/workflows/create-release.yml) [![Luacheckrc](https://github.com/rhagelstrom/Exhausted/actions/workflows/luacheck.yml/badge.svg)](https://github.com/rhagelstrom/Exhausted/actions/workflows/luacheck.yml) [![Markdownlint](https://github.com/rhagelstrom/Exhausted/actions/workflows/markdownlint.yml/badge.svg)](https://github.com/rhagelstrom/Exhausted/actions/workflows/markdownlint.yml)

**Current Version:** ~dev_version~
**Last Updated:** ~date~

**Exhausted** is a 5E extension for FantasyGrounds that introduces exhaustion as a condition, along with various immunities to it. This extension automates the management of exhaustion levels, summing them when applied and decrementing them upon taking a long rest.

## Key Features

* **STAYEXHAUST Effect**: Prevents exhaustion levels from decrementing during a long rest.
* **Automatic Parsing**: NPC Sheets and spells recognize exhaustion conditions, noting "target is exhaustion" or "gain(s)/suffer(s) (N) level(s) of exhaustion".
* **Tireless**: Support for 2024 Tireless Ranger Feature

> **Note**: If using SilentRuin's Generic Actions extension, ensure **Verify Cast Effect** is set to "off".

## Options

| Name| Default | Options | Notes |
| --- | --- | --- | --- |
| **House Rule: Add Exhaustion if heal 0 HP**  | Off | Off, One, Two, Three, Four, Five, Six | Adds specified levels of exhaustion when healed from 0 HP |
| **House Rule: Affect Spell Save DC for d20 roll** | Off | Off, On | When using minus d20 rules, also affect the spell save DC |
| **House Rule: Exhaustion is minus to d20 roll** | Off| Off, One, Two, Three | Applies a penalty to d20 rolls due to exhaustion; overrides Legacy and 2024 settings |
| **House Rule: Exhaustion NPC if heal 0 HP** | Off | Off, All, Friend, Foe, Neutral | Adds levels of exhaustion to NPCs when healed from 0 HP  |
