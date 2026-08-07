# OJT Progress Report — Week 3, Day 4

**Project:** Cosmic Fiends (Godot 4 port)
**Note:** Day 3 was not a working day — attended a required academic talk at PUP.

---

## Summary of Work Done

- Fixed a crash in the Ship Status panel caused by a mismatched node reference.
- Gave each weapon its own ammo capacity and pierce value, with reloading required on weapon switch and a manual reload key added.
- Rebalanced skills: scaled Shockwave damage to hero level, added a speed bonus to Energy Overdrive, and built a new charge-up skill (Purple) from scratch.
- Reduced passive health regeneration and added occasional multi-enemy swarm spawns.
- Fixed the overworld wall depth-sorting bug (player passing in front of/behind walls).
- Reworked difficulty into 4 tiers (Beginner/Normal/Hard/Space Cowboy) with per-tier enemy rosters and health/damage scaling.
- Fixed enemies hitting the player from outside their actual collision range.
- Tied each boss to its own solar system and scaled enemy health with hero level.
- Built the full level-up module/upgrade system: the 3-card selection screen, the complete upgrade table across all rarities, burn/paralysis status effects, and reusable module effect scenes.
- Implemented the module "surrender for currency" system and rarity-based module chests.
- Rebuilt the inventory with a slide-in panel, a cooldown-icon sidebar, live stat display, and a scrollable module log — all as editable scene nodes.
- Fixed the inventory blocking the player from shooting while open.
- Fixed particle effects (deaths, projectile pops) never appearing on screen.
- Fixed melee weapons using outdated collision shapes instead of their authored ones.
- Increased slasher detection range and rebalanced module damage against enemy health scaling.
- Added a small damage increase per player level to offset rising enemy health.
- Set the testing level to spawn all enemy types at once, and expanded enemy collision layers from 3 to 6 groups.

## Problems Faced

Several bugs this session were the kind that don't announce themselves — the code runs without errors, but something is silently wrong. The Ship Status panel crashed because a scene node had been renamed without updating the script that referenced it. The overworld depth-sorting never worked because the two detection colliders were placed in the same spot and were listening for the wrong kind of collision signal, so they simply never fired. Enemies were able to hit the player from well outside their sprites because contact range was a flat number disconnected from the actual collision shapes. While testing the new upgrade system, damage values exploded into the trillions because a "+20% damage" upgrade was compounding off the current total instead of a fixed base. The inventory's stat list and module list would silently double in size every time they refreshed, since removing old entries doesn't take effect until the end of the frame, so rebuilding the list too early stacked duplicates on top of not-yet-removed ones. Two of the more frustrating bugs were effects that looked like they simply didn't exist: death/pop particle effects were saved with emission turned off and nothing ever turned it back on, so they never appeared and quietly piled up unused nodes in the background; and melee weapon collisions kept behaving like their old, already-fixed hitboxes because a shared script was overwriting every weapon's custom collision shape with a generic circle on every single spawn. Finally, clicking the inventory tab was also being read as a shot being fired, since both actions shared the same mouse input with no way to tell them apart.

## How It Was Solved

Each problem was tracked down by checking actual runtime behavior rather than assuming the code was correct from a read-through — in several cases, a small throwaway test script was used inside the engine to print out exactly what was happening (which weapon was firing, what collision shape a projectile had, how many nodes existed after an effect played) before making a fix. The Ship Status crash was fixed by correcting the node path to match the current scene. The depth-sorting bug was fixed by repositioning the two colliders correctly and switching to checking for physics bodies instead of areas, since walls are bodies. Enemy contact range was recalculated from the real collision radii of both the enemy and the player instead of a flat guess. The damage-scaling bug was fixed by having percentage upgrades calculate off the player's starting stat rather than the current one, preventing compounding. The duplicating list bug was fixed by explicitly removing old entries from the scene tree before freeing them, rather than relying on the automatic cleanup timing. The missing particle effects were fixed by having effects turn their emission on automatically when they spawn, with a backup timer so a node can never get stuck around forever. The melee weapon collision bug was fixed by only generating a fallback collision shape when a weapon scene doesn't already have one of its own, instead of always overwriting it. Lastly, the shooting-while-clicking-inventory issue was fixed by adding a short flag that marks a click as "used by the UI" until that mouse button is released, so the same press can't also count as firing a weapon.
