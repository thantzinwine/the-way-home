## Tunable economy numbers. One resource, editable in the inspector, so balancing
## never requires touching gameplay code.
##
## Steps are a currency for movement, not a footstep counter: one cell of travel
## costs `cost_per_cell` Steps.
class_name StepsConfig
extends Resource

## Steps Ren starts the chapter with.
@export var starting_steps := 150

## Steps charged per grid cell travelled (a diagonal two-cell move therefore costs 2).
@export var cost_per_cell := 1

## Lore: how long a frozen person has before they Depart.
@export var departure_hours := 24

## How many real seconds that 24 hour window takes to play out. Accelerated for the
## prototype so the countdown is visible without waiting a real day.
@export var departure_real_seconds := 180.0

## Balance at or below this shows the HUD in its warning colour.
@export var low_steps_threshold := 20
