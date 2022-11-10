# Exhausted

**Current Version:** 1.12
**Last Updated:** 11/09/22

5E extension for FantasyGrounds that adds exhaustion as a condition as well as immunities to the exhaustion condition

This extension also automates the exhaustion stack by summing exhaustion levels when applied and decrementing them on long rest. Also support for Mad Nomads Character Sheet Effects Display extension.

NPC Sheets and spells will automatically parse exhaustion as a condition with the text "target is exhaustion" or "gain(s)/suffer(s) (N) level(s) of exhaustion".

**Note:** If using SilentRuin's Generic Actions extension, Verify Cast Effect must be set to "off" in that extension

## Options

| Name| Default | Options | Notes |
|---|---|---|---|
|Combat: Add Exhaustion if heal 0 HP| Off| Off,One,Two,Three,Four,Five,Six| Adds specified number of levels of exhaustion when healed from 0 HP|
|Combat: Exhaustion NPC if heal 0 HP| Off| Off,All,Friend,Foe,Neutral| Adds level(s) of exhaustion to NPCs if healed from 0 HP|
|CT: Verbose Exhaustion| Off| Off,MNM,Verbose|Adds extra text to support Mad Nomads Character Sheet Display Extension|
|Playtest: Use One DnD exhausted rules| Off| Off,On|Use One DnD playtest rules for Exhaustion/Exhausted instead of 5E|
