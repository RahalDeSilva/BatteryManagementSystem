# BatteryManagementSystem
EKF-based State of Charge estimator for Li-ion cells using NASA battery dataset

> ⚠️ Active development — ongoing BMS prototype. Expect breaking changes between commits.

A MATLAB-based Battery Management System (BMS) prototype focused on State of Charge (SOC) estimation for lithium-ion cells. Currently implements an Extended Kalman Filter (EKF) with a first-order RC equivalent circuit model, validated against a parallel Coulomb Counting benchmark using the NASA battery dataset.

---

## Current Status

| Module | Status |
|---|---|
| EKF SOC Estimator | ✅ In progress |
| Coulomb Counting benchmark | ✅ In progress |
| OCV–SOC lookup table | ✅ In progress |
| Cell balancing | 🔲 Planned |
| Thermal modelling | 🔲 Planned |
| State of Health (SOH) | 🔲 Planned |
| Embedded deployment | 🔲 Planned |

## Status (as of this checkpoint)
- ✅ EKF SOC estimation working on NASA 00001.csv (single discharge cycle)
- ✅ Variable timestep handling (9.4-13.9s)
- ✅ Current sign convention corrected (NASA: discharge = negative)
- ✅ Nonlinear OCV lookup table (extended range + densified knee region)
- 📊 Operational Voltage RMSE: 0.061 V (excludes end-of-discharge relaxation)
- 📌 Known limitation: residual spikes during end-of-discharge relaxation
  (1st-order RC model limitation — see Future Work)
- 📌 EKF vs Coulomb Counting gap (~3.4pp) likely due to placeholder
  capacity Q=2.0Ah vs actual aged-cell capacity — candidate for SOH module

---

## Battery Model

First-order RC equivalent circuit.

**State vector:** `x = [SOC, Vrc]`

**State equations:**

```
SOC(k+1) = SOC(k) − I·dt / Q
Vrc(k+1) = α·Vrc(k) + β·I

α = exp(−dt / (R1·C1))
β = R1·(1 − α)
```

**Terminal voltage measurement equation:**

```
V = OCV(SOC) − I·R0 − Vrc
```

---

## Repository Structure

```
BatteryManagementSystem/
├── SOC_Estimation/
    ├── data/
│       └── 00001.csv         % NASA Li-ion discharge dataset
│   ├── main.m            % EKF loop + Coulomb counting + plots
│   ├── battery_step.m    % RC circuit state transition function
│   ├── ekf_step.m        % EKF predict and update step
│   ├── ocv.m             % Nonlinear OCV piecewise-linear lookup
│   └── load_data.m       % NASA dataset loader
└── README.md
```

---

## Requirements

- MATLAB R2020a or later
- No additional toolboxes required for current modules

---

## Dataset

NASA battery discharge dataset (00001.csv).
Columns: `Voltage_measured`, `Current_measured`, `Temperature_measured`, `Current_load`, `Voltage_load`, `Time`

> Note: NASA dataset uses a non-standard current sign convention. Discharge current is negated in `load_data.m` before processing.

---

## EKF Tuning Parameters

| Parameter | Value | Description |
|---|---|---|
| Q | 2.0 Ah | Nominal cell capacity |
| R0 | ~0.05 Ω | Series resistance |
| R1 | ~0.02 Ω | RC branch resistance |
| C1 | ~2000 F | RC branch capacitance |
| Qk(1,1) | 1e-7 | Process noise — SOC |
| Qk(2,2) | 1e-5 | Process noise — Vrc |
| Rk | 4e-4 | Measurement noise (0.02V std) |

---

## References

- Gregory Plett, *Algorithms for Battery Management Systems* — Coursera
- NASA Prognostics Center of Excellence Battery Dataset
- Plett, G.L., *Battery Management Systems, Vol. 1: Battery Modeling*

---

## License

MIT License — see `LICENSE` for details.