# VB3 Companion Toolbox

## Project

VB3 Companion Toolbox

---

## Version

v5.1-dev

---

## Repository

https://github.com/lisiweilisi-hub/VB3_Companion_Toolbox

---

## Status

Architecture Frozen

---

## Current Phase

Integration

---

## Current Milestone

Milestone 2 — Toolbox Integration

---

## Current RC

RC014.1

---

## Current Module

SPT_RunPipeline Integration

---

# Frozen Modules

```
RC001  Regression Harness                     ✓ Frozen
RC002  Geometry Provider                      ✓ Frozen
RC003  Kinematics Step                        ✓ Frozen
RC004  Kinematics Trajectory                  ✓ Frozen
RC005  Kinematics Confinement                 ✓ Frozen
RC006  Kinematics Turning Angle               ✓ Frozen
RC007  Kinematics TrajectorySamples           ✓ Frozen
RC008  Kinematics MSD                         ✓ Frozen
RC009  Kinematics Diffusion                   ✓ Frozen
RC010  Kinematics State Classification        ✓ Frozen
RC011  Analysis Pipeline Integration          ✓ Frozen
RC012  TurningBehavior                        ✓ Frozen
RC013  StateClassification Fusion             ✓ Frozen
```

---

# Current Work

## RC014.1 — Pipeline Integration

**Status**

In Progress

**Objectives**

- Integrate the frozen Kinematics pipeline into `SPT_RunPipeline`
- Keep Legacy and Kinematics pipelines running in parallel
- Preserve all legacy analysis modules
- Introduce `Project.Analysis.Kinematics` as an independent namespace
- Do not modify legacy outputs

---

# Next

## RC014.2 — Kinematics Export

**Objectives**

- Export every Kinematics module
- Save CSV outputs
- Save MAT outputs
- Create independent output directory

```
Output/
└── Kinematics/
    ├── CSV/
    └── MAT/
```

Modules to export:

- TrajectorySamples
- Step
- Trajectory
- MSD
- Diffusion
- Confinement
- TurningAngle
- TurningBehavior
- StateClassification

---

## Future Roadmap

RC014.3 — CSV Verification

- Compare Legacy and Kinematics numerical outputs

RC014.4 — Figure Integration

- Generate figures directly from Kinematics outputs

RC014.5 — Legacy Replacement

- Replace legacy analysis modules after verification