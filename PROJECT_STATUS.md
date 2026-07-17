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

RC010 — Frozen

Current Module

SPT_Kinematics_StateClassification

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

MATLAB tests passed: 70/70

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

No frozen modules were modified.

No test files were modified.

Other pre-existing worktree changes were untouched.

Next

RC010 Kinematics State Classification complete and frozen.

