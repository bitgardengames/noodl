# Structural Consistency & Modularity Review

This document captures opportunities to standardize module patterns, naming, and shared systems across the Lua codebase.

## Module Interface Conventions

Most gameplay modules follow a `local Module = {}` pattern and return the table at the end of the file (e.g., `snake.lua`, `game.lua`, `shop.lua`).【F:snake.lua†L1-L59】【F:snake.lua†L2106-L2143】【F:game.lua†L1-L39】【F:shop.lua†L1-L59】 A few utilities export raw functions instead of module tables—`drawword.lua` returns a callable function without additional metadata, which diverges from the majority interface.【F:drawword.lua†L1-L67】 Unifying on explicit module tables (or a consistent `local M = {}` + `return M` convention) will simplify dependency expectations, allow feature flags to live alongside behavior, and make it easier to expand simple helpers without breaking callers.

Recommendation:

* Adopt a shared module template that always returns a table, even when exposing a single function. For helper-only modules, export the function as `M.run` (or similar) to keep the public surface explicit.
* Formalize module init hooks (`:load`, `:reset`, `:update`, `:draw`) for systems that need lifecycle management, so orchestrators like `Game` can reason about subsystems uniformly.【F:gameutils.lua†L1-L59】【F:gameutils.lua†L60-L80】

## Naming & Layer Boundaries

`Game` currently orchestrates simulation state, rendering layers, transition effects, and input dispatching inside one file.【F:game.lua†L280-L360】【F:game.lua†L960-L1040】【F:game.lua†L1401-L1480】 Breaking this into dedicated modules (`GameStateManager`, `GameRenderer`, `GameInputRouter`) would reduce cross-cutting dependencies and make responsibilities clearer. Likewise, singleton-style modules (`Popup`, `FloatingText`, `UI`) hold mutable state at module scope, which complicates testing and reuse.【F:popup.lua†L1-L58】【F:floatingtext.lua†L1-L80】 Encapsulating state inside returned tables (or providing constructors) would let multiple screens instantiate their own instances when needed.

Recommendation:

* Split `game.lua` into smaller modules aligned to concerns: one managing simulation and timers, one orchestrating draw order, and one translating raw `love` events into high-level actions.
* Refactor global singletons that depend on UI fonts or screen metrics so they can be instantiated/configured explicitly, avoiding tight coupling to `UI` or `Screen` within their modules.【F:floatingtext.lua†L1-L44】【F:popup.lua†L1-L71】

## Shared Timer & Animation Utilities

Timers, easing functions, and clamp helpers are reimplemented across multiple modules (`floatingtext.lua`, `popup.lua`, `snake.lua`, among others).【F:floatingtext.lua†L57-L80】【F:popup.lua†L18-L52】【F:snake.lua†L866-L895】 A dedicated `Timer`/`Tween` utility with a consistent API (e.g., `Timer.start(duration)`, `Timer:update(dt)`, `Tween.ease(method, progress)`) would eliminate repeated logic and reduce subtle inconsistencies (different fade-in/out thresholds, varying clamp implementations).

Recommendation:

* Introduce a `timers.lua` utility that can manage countdowns, loops, and hit-stop style pauses with consistent semantics. Systems such as Snake abilities, popup notifications, and combo timers could share this API instead of manually adjusting `timer` fields.【F:snake.lua†L866-L895】【F:popup.lua†L18-L52】
* Extract easing/lerp helpers into a consolidated math utility, or expand the existing `easing.lua`, so modules can import shared implementations rather than declaring local copies.【F:floatingtext.lua†L57-L80】

## Input, Render, and State Separation

`Game` handles keyboard routing, shop forwarding, pause menu interaction, render ordering, and transition confirmation all in one module.【F:game.lua†L960-L1040】【F:game.lua†L1422-L1480】 Centralizing each concern in its own module would make it easier to plug in new states or accessibility options. For example, an `InputRouter` could coordinate between gameplay, shop, and pause contexts, while a `RenderPipeline` module could organize draw phases (background, actors, overlays) independent of simulation state.

Recommendation:

* Move raw Love2D event handling into a dedicated router that understands active contexts and delegates to subsystems, keeping `Game` focused on gameplay state transitions.
* Encapsulate draw order and special overlays (developer assist badge, transition overlays) inside a renderer module so visual changes do not touch simulation logic.【F:game.lua†L969-L1040】【F:game.lua†L1006-L1040】

## Detecting Redundant Patterns

Scanning the codebase shows repeated timer-based fade/bounce implementations (`Popup:update`, floating text wobble/fade, Snake ability cooldowns) and duplicated clamp logic. A shared library combined with linting/tests could flag new bespoke timers or math helpers when a shared version exists.【F:popup.lua†L18-L52】【F:floatingtext.lua†L57-L80】【F:snake.lua†L866-L895】 Establishing conventions for naming (`timer`, `duration`, `cooldownTimer`) and lifecycle methods will help highlight when a module diverges.

Recommendation:

* Add a lightweight static check (or PR checklist) ensuring new modules reference shared utilities instead of redefining timers or easing functions.
* Consolidate naming for timer-related fields (`*_timer`, `*_duration`, `*_cooldown`) and document them in a style guide so cross-module data (e.g., UI overlays consuming Snake ability timers) stays consistent.【F:snake.lua†L866-L895】

Implementing these changes will make it easier to expand gameplay features, reduce bugs from duplicated logic, and improve maintainability across the Lua subsystems.
