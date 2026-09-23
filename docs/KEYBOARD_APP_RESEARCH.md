# Physical-Keyboard App Research Plan

**Status:** exploratory application research while SableOS Release 9 validation continues

The goal is not to duplicate existing keyboard-phone work blindly. The immediate task is to understand which pieces should be reused, adapted, or treated as reference material for a future SableOS physical-keyboard experience.

## Current direction

Do **not** start by writing a brand-new IME from scratch.

First:

1. characterize Titan 2 physical-key events and stock keylayout behavior;
2. evaluate Pastiera as the strongest existing IME baseline;
3. separate IME concerns from OS-level key remapping and accessibility/navigation features;
4. define a device-profile format that can later cover Titan 2, Titan 2 Elite and Q27;
5. keep keyboard-first application UX as a separate concern from the IME itself.

## Pastiera

Repository:

https://github.com/palsoftware/pastiera

Pastiera is explicitly designed for physical-keyboard Android devices and currently names Titan 2 as a primary target.

Useful existing features include:

- physical-keyboard-focused IME behavior;
- QWERTY/AZERTY/QWERTZ and other layouts;
- dedicated Titan 2 Alt maps;
- JSON layout import/export;
- modifier state and one-shot/lock behavior;
- configurable navigation/shortcut mappings;
- launcher and power shortcuts;
- compact UI intended to preserve vertical screen space;
- device/firmware behavior archives;
- regression tests around modifier and routing behavior.

Pastiera's Titan 2 archive records behavior from real hardware and specific firmware rather than treating it as timeless device truth. That evidence style is worth preserving for SableOS device profiles.

Pastiera also contains Titan 2 Elite display/device notes, including near-square viewport geometry, rounded-corner handling and an important device-identification warning: a final Titan 2 Elite can report several Titan-2-like product/fingerprint values, so device detection should not rely on a build fingerprint alone.

**License:** GPLv3.

Any direct code reuse/fork decision must account for that license. It is also valid to use Pastiera as a behavioral/reference implementation while keeping separately written SableOS components under their own chosen license.

## Commander

Repository:

https://github.com/astroboii47/Commander

Commander is not an IME. It is useful as a **keyboard-first Android UX reference**.

It is a searchable command bar / notification hub designed around typing and hardware-key navigation and has been tested primarily on:

- Unihertz Titan 2;
- Zinwa Q25.

It demonstrates a broader design principle for SableOS keyboard devices: the physical keyboard should be treated as a first-class navigation/input surface, not merely as a text-entry accessory.

**License:** MIT.

Potential lessons for SableOS:

- fast app/action search;
- keyboard-operated recent-app switching;
- discoverable shortcut hints;
- hardware-key launch paths;
- keyboard-driven system actions;
- keeping touch support without making touch the only efficient path.

## q25toolbox

Repository:

https://github.com/nozerorma/q25toolbox

q25toolbox is useful primarily as a lower-level reference for Zinwa/Q25-specific integration.

Its project documentation describes patterns such as:

- physical-key remapping;
- Android keylayout replacement;
- accessibility-service event handling;
- pass-through IME behavior;
- root-backed device tweaks;
- lockscreen/key handling;
- separating stateless root commands from long-lived state observation.

Those are useful examples of where a feature belongs at the Android input/OS layer rather than inside a normal IME.

A root-level `LICENSE` file was not found during this review. Treat direct code reuse as **license-unresolved** until the repository's applicable licensing terms are established.

## Titan 2 / Titan 2 Elite community references

The Unihertz Discord server, especially the community channels described by the project owner as `kernel-studies` and `rooting-and-custom-stuff`, is a useful discovery source.

Discord discussion should not become repository "fact" merely because it was posted there. Any important keyboard/camera claim taken from chat should be converted into one of:

- reproducible device output;
- a source-code reference;
- a firmware/static-analysis artifact;
- a clearly attributed community observation.

This keeps the public repository auditable even when the discovery conversation is not permanently public.

## Device-profile direction

A future cross-device keyboard layer should distinguish common behavior from hardware-specific behavior.

Possible profile shape:

```text
device-profile
  identity
    model
    board
    build-display patterns
    safe fallback identifiers

  physical keyboard
    keycode/scancode observations
    modifier keys
    symbol key
    programmable/special keys
    wake behavior

  Android integration
    .kl/.kcm files
    framework remaps
    accessibility quirks
    IME behavior

  UI geometry
    display size
    density
    cutout
    rounded corners
    safe areas

  app shortcuts
    launcher actions
    navigation defaults
    camera shutter / camera controls
```

Do not key the entire profile solely off a marketing model string or fingerprint.

## Relationship to Sable Camera

The camera and keyboard projects should share a keyboard-control abstraction.

For a keyboard phone, useful camera bindings may include:

- half/first-stage focus if hardware exposes a suitable key;
- shutter;
- start/stop video;
- zoom in/out;
- switch front/rear;
- switch main/tele when allowed;
- exposure compensation;
- focus lock;
- open gallery;
- mode/settings navigation.

Those bindings should be configurable and device-profile aware rather than hard-coded globally.

## Q27 scope

Wait for newer/current Q27 OTA releases and preferably shipping hardware.

Prototype OTA files can later help identify:

- keylayout / key-character-map files;
- keyboard drivers and framework hooks;
- camera HAL/provider configuration;
- stock camera/keyboard packages;
- vendor-specific input services.

Prototype observations must remain clearly labeled as prototype evidence and must not be generalized to retail Q27 behavior.

## Near-term work order

While SableOS Release 9 remains under Pixel 7 validation:

```text
1. finish Titan 2 Camera2 capability baseline
2. build reusable Camera Probe
3. collect Titan 2 physical-keyboard event/keylayout baseline
4. evaluate Pastiera behavior on Titan 2
5. define shared device-profile schema
6. defer Titan 2 Elite/Q27 active work until hardware/current firmware evidence is ready
7. resume SableOS OS bring-up only after Pixel 7 Release 9 validation
```

This keeps application research productive without reopening the already-closed Titan 2 boot/firmware research phase.
