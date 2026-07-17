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

RC008 — Frozen

Current Module

SPT_Kinematics_MSD

Status

RC001 Regression Harness            ✓ Frozen

RC002 Geometry Provider             ✓ Frozen

RC003 Kinematics Step               ✓ Frozen

RC004.1A Trajectory Skeleton  ✓ Frozen

RC004.2 Trajectory Core       ✓ Frozen

RC004.3 Trajectory Tests      ✓ Frozen

RC004.4 Trajectory Refinement ✓ Frozen

RC004 Kinematics Trajectory         ✓ Frozen

RC005.1 Confinement Skeleton   ✓ Frozen

RC005.2 Confinement Core       ✓ Frozen

RC005.3 Confinement Tests      ✓ Frozen

RC005.4 Confinement Refinement ✓ Frozen

RC005 Kinematics Confinement        ✓ Frozen

RC006.1 Turning Angle Skeleton   ✓ Frozen

RC006.2 Turning Angle Core       ✓ Frozen

RC006.3 Turning Angle Tests      ✓ Frozen

RC006.4 Turning Angle Refinement ✓ Frozen

RC006 Kinematics Turning Angle      ✓ Frozen

RC007.1 TrajectorySamples Skeleton  ✓ Frozen

RC007.2 TrajectorySamples Core      ✓ Frozen

RC007.3 TrajectorySamples Tests     ✓ Frozen

RC007.4 TrajectorySamples Refinement ✓ Frozen

RC007 Kinematics TrajectorySamples  ✓ Frozen

RC008.1 MSD Skeleton                ✓ Frozen

RC008.2 MSD Core                    ✓ Frozen

RC008.3 MSD Tests                   ✓ Frozen

RC008.4 MSD Refinement              ✓ Frozen

RC008 Kinematics MSD                ✓ Frozen

MATLAB tests passed: 52/52

Public API:

ByTrack

Ensemble

Summary

Validation

Per-track MSD, X/Y components, pair counts, pooled ensemble MSD, trajectory mean/SEM, and actual lag times were added

Refinement: nonfinite displacement, squared-distance, or lag-time calculations now fail validation and suppress partial MSD results

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

Data source: Project.Analysis.Kinematics.TrajectorySamples

Public output: Project.Analysis.Kinematics.MSD

No frozen modules were modified.

No test files were modified.

Next

RC008 Kinematics MSD complete and frozen.

