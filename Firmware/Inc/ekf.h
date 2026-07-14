#ifndef EKF_H
#define EKF_H

#include <stdint.h>

/* -----------------------------------------------------------------------
 * Battery model parameters
 * Equivalent circuit: OCV(SOC) - R0 - [R1 || C1]
 * ----------------------------------------------------------------------- */
#define BATT_Q      2.0f        /* Capacity (Ah) — placeholder, update when measured */
#define BATT_R0     0.01f       /* Series resistance (Ohm)                           */
#define BATT_R1     0.005f      /* RC branch resistance (Ohm)                        */
#define BATT_C1     3000.0f     /* RC branch capacitance (F)                         */

/* -----------------------------------------------------------------------
 * EKF noise tuning
 * ----------------------------------------------------------------------- */
#define EKF_Q00     1e-7f       /* Process noise: SOC state                          */
#define EKF_Q11     1e-5f       /* Process noise: Vrc state                          */
#define EKF_R       4e-4f       /* Measurement noise: voltage variance (0.02V std)   */

/* -----------------------------------------------------------------------
 * EKF state structure
 * ----------------------------------------------------------------------- */
typedef struct {
    float soc;      /* State of Charge (0.0 to 1.0)      */
    float vrc;      /* RC branch voltage (V)              */

    /* 2x2 error covariance matrix (row-major: P[0]=P00, P[1]=P01,
       P[2]=P10, P[3]=P11) */
    float P[4];
} EKF_State;

/* -----------------------------------------------------------------------
 * Public API
 * ----------------------------------------------------------------------- */

/**
 * @brief  Initialise EKF state before the first sample.
 * @param  state   Pointer to EKF_State to initialise.
 * @param  soc0    Initial SOC estimate (0.0 – 1.0).
 */
void EKF_Init(EKF_State *state, float soc0);

/**
 * @brief  Run one predict + update cycle.
 * @param  state   EKF state (updated in-place).
 * @param  I       Battery current, A  (positive = discharge).
 * @param  V_meas  Measured terminal voltage, V.
 * @param  dt      Elapsed time since last call, s.
 */
void EKF_Update(EKF_State *state, float I, float V_meas, float dt);

/**
 * @brief  OCV–SOC lookup (linear approximation).
 *         Replace with a table interpolation when a measured curve is available.
 * @param  soc  State of Charge (0.0 – 1.0).
 * @return Open-circuit voltage, V.
 */
float OCV_from_SOC(float soc);

#endif /* EKF_H */
