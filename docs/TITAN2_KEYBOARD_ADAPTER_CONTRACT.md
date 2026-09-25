# Titan 2 keyboard adapter contract — draft

Status: **template awaiting static-stack capture**

This document is the implementation-facing output of the Titan 2 keyboard
research. It should be filled from `t2-keyboard-static-map.sh` evidence, not by
copying current stock UX assignments.

## 1. Hardware / kernel capabilities to preserve

| Function | Stable identity | Driver / parent | Wake capability | Sable requirement |
| --- | --- | --- | --- | --- |
| physical key matrix | TitanKey | TBD | TBD | preserve raw key matrix |
| keyboard capacitive surface | touchPad | TBD | TBD | preserve ABS_MT stream |
| upper programmable side key | PMIC path / scan 249 | TBD | yes in tested screen-off state | preserve independent side-key path |
| lower programmable side key | gpio function-key / scan 250 | TBD | input remains live; no tested wake | preserve independent side-key path |
| synthetic helper | ff_key | TBD | TBD | determine whether needed by Sable |
| keyboard illumination | vendor-private backend | TBD | n/a | expose Sable-owned control without assuming Android KbdBacklightController |

Do not hard-code event numbers.

## 2. Android static translation to reproduce or replace deliberately

| Layer | Stock evidence | Sable decision |
| --- | --- | --- |
| `.kl` | TitanKey / Generic mappings | TBD |
| `.kcm` | TitanKey character map | TBD |
| `.idc` | TitanKey / touchPad classification | TBD |
| InputReader extensions | vendor programmable/synthetic-key behavior observed | preserve only hardware-required behavior |
| wake policy | matrix vs side-key behavior differs during screen-off | determine from driver/sysfs/DT evidence |

## 3. Vendor-framework capabilities

### Preserve if they are the only hardware owner

- side-key raw input plumbing;
- rear-display wake plumbing tied to Func1 if implemented below replaceable UI;
- any required touchPad device association/classification;
- keyboard-light backend access if only vendor services can drive it.

### Reimplement in Sable policy

- programmable key assignment;
- shortcut routing;
- camera shutter assignment;
- keyboard-light UX;
- optional touch-surface gestures;
- rear-display presentation policy.

## 4. Stock policy that must not define the hardware contract

Do not treat these as intrinsic keyboard behavior:

- Kika text-composition choices;
- user-configurable shortcut assignments;
- launcher-specific Home/Recents outcomes;
- Mouse Mode pointer policy;
- SubScreen notification allow-list;
- vendor synthetic actions whose hardware source can be represented more directly.

## 5. Acceptance criteria for the first Sable adapter

The first keyboard adapter should prove:

- every required physical key produces the expected Linux/Android/Sable action;
- modifiers and repeat are preserved;
- programmable side keys are distinguishable;
- keyboard touch surface remains independently available;
- screen-off wake behavior is deliberate, not accidental;
- keyboard illumination can be controlled through a documented adapter API;
- no dependency on Kika is required for base hardware input;
- stock-app removal does not remove the only owner of a required hardware function.

## 6. Open fields after static-map capture

Fill these tomorrow:

- TitanKey bound driver / parent bus;
- touchPad bound driver / parent bus;
- ff_key producer;
- Func1/Func2 parent driver and wakeup attributes;
- device-tree wakeup properties, if exposed;
- exact `.kl/.kcm/.idc` precedence;
- whether key 404 is generated in framework or by another input producer;
- keyboard-light lower-level owner/path if discoverable without invasive reverse engineering.

If any field remains vendor-private after static inspection, record the boundary
and defer deeper reverse engineering unless it blocks the first Sable adapter.
