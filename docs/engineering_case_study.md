# Echo Village engineering case study

## Product scope

Echo Village is a Traditional Chinese 2D life-simulation RPG built with Godot 4 and GDScript. The repository covers game systems, NPC decision-making, data-driven content, UI, persistence, automated testing, and Windows packaging.

## Design problem

Residents need to behave as agents with observable reasons and persistent consequences. The simulation also has to remain deterministic enough for testing and continue to work offline, without making core gameplay depend on a hosted language model.

## Architecture

Each resident scores ten actions from needs, personality, schedule, resources, relationships, and current events. A state machine and Godot NavigationAgent execute the selected action. Player interactions create structured memories; memories affect relationships and can propagate between residents. Gifts, theft, trades, and story choices therefore update the same persistent world model instead of isolated UI values.

Implemented systems include:

- five data-driven residents and ten Utility AI actions;
- NPC relationships, long-term memories, decay, propagation, and emotional effects;
- dynamic events, bilateral trading, inventories, recipes, and a multi-stage quest;
- village and forest navigation with two-stage stuck recovery;
- menus, settings, pause flow, HUD, inventory, map, quest journal, and trade UI;
- autosave, versioned serialization, migration, and duplicate-reward protection;
- village reputation, data-driven achievements, onboarding, and a persistent journal;
- causal history with relationship deltas, before/after values, memory importance, and story choices;
- 99 automated tests, 15 GPU visual-QA captures, CI, a daily 90-day simulation soak, tracked-file security scanning, and a portable Windows build.

## Engineering decisions

1. Utility scores are visible in the resident inspector, so decisions can be debugged and balanced.
2. NPCs, events, items, quests, locations, and stories live in validated JSON rather than scene-specific code.
3. Trading, crafting, and quest rewards validate every precondition before committing state.
4. The test runner scans Godot runtime output in addition to evaluating assertions.
5. The Windows build supports portable runtime plus PCK assembly when export templates are unavailable.
6. Onboarding preferences are stored separately from world saves, preventing tutorial state from contaminating gameplay state.
7. Save data and optional-AI context are treated as untrusted input. Size, type, depth, numeric, and collection limits are verified before atomic deserialization.
8. Daily echoes and causal history share a bounded timeline, which keeps consequences explainable without duplicating state.

## Defects caught during development

- Cross-midnight events originally used a time-of-day endpoint. They now use a remaining-duration lifecycle.
- A newly imported AI script could leave an Autoload dependency unresolved. The editor compilation gate and runtime-error scan now catch this class of failure.
- Windows batch files containing localized command text failed under some code pages. Build commands are ASCII-only; localization remains inside the game.
- Early trading used a shortcut purchase. The current service validates inventory, currency, price, and both sides of the transaction before a single commit.

## Current result

Version 1.4.0 provides a playable village-and-forest slice with persistent progression and branching stories. Automated tests cover domain rules, malformed saves, migrations, UI contracts, long-running simulation, and packaging. The architecture leaves explicit boundaries for additional content, controllers, localization, and an optional text-generation provider.
