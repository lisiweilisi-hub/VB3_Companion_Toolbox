\# VB3 Companion Toolbox



Project

VB3 Companion Toolbox



Version

v5.0



Repository

https://github.com/lisiweilisi-hub/VB3\_Companion\_Toolbox



Status

Architecture Frozen



Current Phase

Analysis



Current Milestone

Milestone 1 — Kinematics



Current RC

RC012 — Frozen

Current Module

Project.Analysis.Kinematics.TurningBehavior

Status

RC001 Regression Harness               ✓ Frozen

RC002 Geometry Provider                ✓ Frozen

RC003 Kinematics Step                  ✓ Frozen

RC004.1A Trajectory Skeleton  ✓ Frozen

RC004.2 Trajectory Core       ✓ Frozen

RC004.3 Trajectory Tests      ✓ Frozen

RC004.4 Trajectory Refinement ✓ Frozen

RC004 Kinematics Trajectory            ✓ Frozen

RC005.1 Confinement Skeleton   ✓ Frozen

RC005.2 Confinement Core       ✓ Frozen

RC005.3 Confinement Tests      ✓ Frozen

RC005.4 Confinement Refinement ✓ Frozen

RC005 Kinematics Confinement           ✓ Frozen

RC006.1 Turning Angle Skeleton   ✓ Frozen

RC006.2 Turning Angle Core       ✓ Frozen

RC006.3 Turning Angle Tests      ✓ Frozen

RC006.4 Turning Angle Refinement ✓ Frozen

RC006 Kinematics Turning Angle         ✓ Frozen

RC007.1 TrajectorySamples Skeleton  ✓ Frozen

RC007.2 TrajectorySamples Core      ✓ Frozen

RC007.3 TrajectorySamples Tests     ✓ Frozen

RC007.4 TrajectorySamples Refinement ✓ Frozen

RC007 Kinematics TrajectorySamples     ✓ Frozen

RC008.1 MSD Skeleton                ✓ Frozen

RC008.2 MSD Core                    ✓ Frozen

RC008.3 MSD Tests                   ✓ Frozen

RC008.4 MSD Refinement              ✓ Frozen

RC008 Kinematics MSD                  ✓ Frozen

RC009.1 Diffusion Skeleton          ✓ Frozen

RC009.2 Diffusion Core              ✓ Frozen

RC009.3 Diffusion Tests             ✓ Frozen

RC009.4 Diffusion Refinement        ✓ Frozen

RC009 Kinematics Diffusion            ✓ Frozen

RC010.1 State Classification Skeleton  ✓ Frozen

RC010.2 State Classification Core      ✓ Frozen

RC010.3 State Classification Tests     ✓ Frozen

RC010.4 State Classification Refinement ✓ Frozen

RC010 Kinematics State Classification    ✓ Frozen

RC011.1 Analysis Pipeline Integration    ✓ Frozen

RC011.2 Validation & Failure Injection   ✓ Frozen

RC011.3 Performance Smoke Test           ✓ Frozen

RC011.4 Regression Integration           ✓ Frozen

RC011 Analysis Pipeline Integration      ✓ Frozen

RC012.1 TurningBehavior Skeleton         ✓ Frozen

RC012.2 TurningBehavior Core             ✓ Frozen

RC012.3 TurningBehavior Tests            ✓ Frozen

RC012.4 TurningBehavior Refinement       ✓ Frozen

RC012 Kinematics TurningBehavior         ✓ Frozen

MATLAB tests passed: 81/81

The public output includes:

AngleTable

SegmentTable

ByTrack

Ensemble

Summary

Validation

TurningBehavior summary fields were refined

Signed turning-angle information and contiguous turning segment summaries are covered

No MATLAB source or frozen modules were modified

No other test files were modified

Focused numerical smoke test: passed

The module reads only frozen TrajectorySamples and Trajectory outputs

The standard modular API is exposed

Local and upstream validation status are propagated

Angle-resolved core TurningBehavior calculations were implemented

No frozen MATLAB modules were modified

No test files were modified

Public pipeline integration coverage remains stable

Performance smoke test completed successfully

Validation failure propagation verified

Pipeline does not silently succeed when upstream validation is false

Downstream modules suppress invalid outputs or fail validation

Canonical join key remains DatasetIndex

Pipeline order verified

Public APIs verified

Validation propagation verified

DatasetIndex remained the canonical join key

Public API:

ByTrack

Ensemble

Summary

Validation

Core behavior:

Validated diffusion fits produce BrownianCandidate; unavailable or invalid evidence remains Unclassified

Validation failures suppress classification results

Forbidden input scan: Clean

Added baseline 2D Brownian fitting over the first 10 valid MSD points

D = slope / 4

Invalid, negative-slope, and validation-failed estimates are suppressed

Per-track MSD, X/Y components, pair counts, pooled ensemble MSD, trajectory mean/SEM, and actual lag times were added

Refinement: zero-variance MSD fits no longer report a false perfect R²; undefined estimates are suppressed

Refinement: unsuccessful diffusion fits retaining partial coefficient or R² values now fail validation and suppress classification

Exact focused MATLAB suite completed successfully

Identifier eligibility refinement check: Passed

Focused TrajectorySamples contract check: Passed

Focused TrajectorySamples core check: Passed

Focused Turning Angle skeleton check: Passed

Focused Turning Angle core check: Passed

Eligibility refinement check: Passed

Focused Confinement skeleton check: Passed

Focused Confinement core check: Passed

Source-validation propagation check: Passed

Focused trajectory numerical check: Passed

API renamed: Trajectory.Table -> Trajectory.ByTrack

Inputs: frozen Analysis outputs only

Public output: Project.Analysis.Kinematics.StateClassification

Production MATLAB source files were not modified.

tests/test_AnalysisPipeline.m was updated for RC011.1 through RC011.4.

Pre-existing PROJECT_STATUS.md change was untouched except for this freeze update.

Next

RC012 TurningBehavior complete and frozen.

