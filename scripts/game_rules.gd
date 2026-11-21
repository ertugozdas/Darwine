class_name GameRules extends RefCounted

## Match-wide values shared by the turn manager and the battlefield UI.
const PLAYER_IDS: Array[int] = [1, 2]

const DECK_SIZE := 30
const MAX_CARD_COPIES := 2
const STARTING_CARD_CONTENT_TARGET := 24
const STARTING_HAND_SIZE := 5
const MAX_HAND_SIZE := 8
const CARDS_DRAWN_PER_TURN := 1
## A normal turn still draws one card. If that draw would leave the active
## player below this amount (while cards remain in deck), BattlefieldUI grants
## catch-up draws up to this floor. Empty decks suffer at most one fatigue tick
## per turn start.
const MINIMUM_TURN_START_HAND := 2

const STARTING_ENERGY := 3
const MAX_ENERGY := 10
const PREPARATION_TOKEN_ENERGY := 1
const TACTICAL_SUPPLY_ENERGY_COST := 2
## The player acting second begins with a one-hit Headquarters ward. It absorbs
## opening initiative without changing the shared 30-Health win condition.
const SECOND_PLAYER_HQ_PROTECTION := 1
const MOVEMENT_ENERGY_COST := 1
const SAME_LANE_MOVEMENT_ENERGY_COST := 0
const TURN_DURATION_SECONDS := 30.0

const MAX_CARD_LEVEL := 3
const LEVEL_EXPERIENCE_REQUIREMENTS := {
	2: 2,
	3: 6,
}
const LEVEL_ENERGY_COSTS := {
	2: 1,
	3: 2,
}
const HERO_EXPERIENCE_PER_TURN := 2
const STRUCTURE_EXPERIENCE_PER_TURN := 1

const HEADQUARTERS_HEALTH := 30
const FATIGUE_START_DAMAGE := 1

## Dominion ruleset. Control is intentionally based on fixed card-type values
## instead of level or current stats, so the board state remains readable and
## upgrades do not create a second snowballing multiplier.
const DOMINION_SCORE_TARGET := 12
const DOMINION_HERO_CONTROL := 2
const DOMINION_STRUCTURE_CONTROL := 1
