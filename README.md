
# Exhausted

[![Build FG Extension](https://github.com/rhagelstrom/Exhausted/actions/workflows/create-release.yml/badge.svg)](https://github.com/rhagelstrom/Exhausted/actions/workflows/create-release.yml) [![Luacheckrc](https://github.com/rhagelstrom/Exhausted/actions/workflows/luacheck.yml/badge.svg)](https://github.com/rhagelstrom/Exhausted/actions/workflows/luacheck.yml) [![Markdownlint](https://github.com/rhagelstrom/Exhausted/actions/workflows/markdownlint.yml/badge.svg)](https://github.com/rhagelstrom/Exhausted/actions/workflows/markdownlint.yml)

**Current Version:** ~dev_version~ \
**Last Updated:** ~date~

5E extension for FantasyGrounds that adds exhaustion as a condition as well as immunities to the exhaustion condition.

This extension also automates the exhaustion stack by summing exhaustion levels when applied and decrementing them on long rest. The effect **STAYEXHAUST** can be used to prevent exhaustion level from being decremented on rest. Also support for Mad Nomads Character Sheet Effects Display extension.

NPC Sheets and spells will automatically parse exhaustion as a condition with the text "target is exhaustion" or "gain(s)/suffer(s) (N) level(s) of exhaustion".

**Note:** If using SilentRuin's Generic Actions extension, Verify Cast Effect must be set to "off" in that extension.

## Options

| Name| Default | Options | Notes |
|---|---|---|---|
|CT: Verbose Exhaustion| Off| Off,MNM,Verbose|Adds extra text to support Mad Nomads Character Sheet Display Extension 2014 only|
|House Rule: Add Exhaustion if heal 0 HP| Off| Off,One,Two,Three,Four,Five,Six| Adds specified number of levels of exhaustion when healed from 0 HP|
|House Rule: House Rule: Exhaustion is minus to d20 roll| Off| Off,One,Two,Three| Use minus to d20 rule for exhaustion. Override Legacy and 2024 settings|
|House Rule: Exhaustion NPC if heal 0 HP| Off| Off,All,Friend,Foe,Neutral| Adds level(s) of exhaustion to NPCs if healed from 0 HP|
