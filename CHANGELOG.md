# CHANGELOG

## v5.1-dev

### Milestone 2 --- Toolbox Integration

Current development branch.

------------------------------------------------------------------------

## RC014.1 --- Pipeline Integration *(In Progress)*

### Objectives

-   Integrate the frozen Kinematics pipeline into `SPT_RunPipeline`
-   Run Legacy and Kinematics pipelines in parallel
-   Preserve all legacy analysis modules
-   Introduce `Project.Analysis.Kinematics`
-   Do not modify legacy outputs

------------------------------------------------------------------------

## Planned RC014.2 --- Kinematics Export

### Objectives

-   Export all Kinematics modules to CSV
-   Export MAT files
-   Create independent output directory:

``` text
Output/
└── Kinematics/
    ├── CSV/
    └── MAT/
```

Modules:

-   TrajectorySamples
-   Step
-   Trajectory
-   MSD
-   Diffusion
-   Confinement
-   TurningAngle
-   TurningBehavior
-   StateClassification

------------------------------------------------------------------------

## Planned RC014.3 --- CSV Verification

Compare Legacy and Kinematics numerical outputs.

------------------------------------------------------------------------

## Planned RC014.4 --- Figure Integration

Generate figures directly from Kinematics outputs.

------------------------------------------------------------------------

## Planned RC014.5 --- Legacy Replacement

Replace legacy analysis modules after numerical verification.

------------------------------------------------------------------------

# Historical Releases

## v5.0

### Milestone 1 --- Kinematics (Frozen)

Frozen modules:

-   RC001 Regression Harness
-   RC002 Geometry Provider
-   RC003 Kinematics Step
-   RC004 Kinematics Trajectory
-   RC005 Kinematics Confinement
-   RC006 Kinematics Turning Angle
-   RC007 Kinematics TrajectorySamples
-   RC008 Kinematics MSD
-   RC009 Kinematics Diffusion
-   RC010 Kinematics State Classification
-   RC011 Analysis Pipeline Integration
-   RC012 TurningBehavior
-   RC013 StateClassification Fusion

Status:

-   Architecture Frozen
-   MATLAB test suite passed
-   Kinematics API frozen
