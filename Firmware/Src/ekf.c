#include <ekf.h>
#include <math.h>

/* -----------------------------------------------------------------------
 * OCV–SOC relationship
 * Linear approximation: OCV = 3.0 + 1.2*SOC
 * Covers ~3.0 V (empty) to ~4.2 V (full) for a Li-ion cell.
 * TODO: replace with a measured lookup table once cell characterisation
 *       data is available.
 * ----------------------------------------------------------------------- */
float OCV_from_SOC(float soc)
{
    return 3.0f + 1.2f * soc;
}

/* -----------------------------------------------------------------------
 * EKF_Init
 * ----------------------------------------------------------------------- */
void EKF_Init(EKF_State *state, float soc0)
{
    state->soc  = soc0;
    state->vrc  = 0.0f;

    /* Initial covariance — moderate uncertainty on SOC, low on Vrc */
    state->P[0] = 0.01f;   /* P00 */
    state->P[1] = 0.0f;    /* P01 */
    state->P[2] = 0.0f;    /* P10 */
    state->P[3] = 0.001f;  /* P11 */
}

/* -----------------------------------------------------------------------
 * EKF_Update  — one predict + update cycle
 *
 * State vector:  x = [SOC, Vrc]
 *
 * State equations:
 *   SOC(k+1) = SOC(k) - I*dt / (Q*3600)
 *   Vrc(k+1) = alpha*Vrc(k) + beta*I
 *   where alpha = exp(-dt / (R1*C1))
 *         beta  = R1 * (1 - alpha)
 *
 * Observation:
 *   V_pred = OCV(SOC) - I*R0 - Vrc
 *
 * Jacobians:
 *   A = [[1, 0], [0, alpha]]          (state transition)
 *   H = [[dOCV/dSOC, -1]]             (observation)
 * ----------------------------------------------------------------------- */
void EKF_Update(EKF_State *state, float I, float V_meas, float dt)
{
    /* ---- 0. Pre-compute RC decay coefficients ---- */
    float alpha = expf(-dt / (BATT_R1 * BATT_C1));
    float beta  = BATT_R1 * (1.0f - alpha);

    /* ---- 1. State prediction ---- */
    float soc_pred = state->soc - (I * dt) / (BATT_Q * 3600.0f);
    float vrc_pred = alpha * state->vrc + beta * I;

    /* Clamp SOC to valid range */
    if (soc_pred > 1.0f) soc_pred = 1.0f;
    if (soc_pred < 0.0f) soc_pred = 0.0f;

    /* ---- 2. Covariance prediction:  P = A*P*A' + Q ----
     * A = [[1, 0], [0, alpha]]
     * Written out element-wise to avoid any matrix library dependency.
     * P indices: [0]=P00, [1]=P01, [2]=P10, [3]=P11
     */
    float p00 = state->P[0];
    float p01 = state->P[1];
    float p10 = state->P[2];
    float p11 = state->P[3];

    float Pp00 = p00                   + EKF_Q00;
    float Pp01 = alpha * p01;
    float Pp10 = alpha * p10;
    float Pp11 = alpha * alpha * p11   + EKF_Q11;

    /* ---- 3. Measurement prediction ---- */
    float dOCV_dSOC = 1.2f;            /* derivative of OCV w.r.t. SOC  */
    float V_pred = OCV_from_SOC(soc_pred) - I * BATT_R0 - vrc_pred;

    /* ---- 4. Innovation ---- */
    float innov = V_meas - V_pred;

    /* ---- 5. Innovation covariance:  S = H*P*H' + R
     * H = [dOCV_dSOC, -1]
     * S = dOCV_dSOC^2 * Pp00
     *   - dOCV_dSOC   * Pp01
     *   - dOCV_dSOC   * Pp10
     *   + Pp11
     *   + R
     */
    float S = dOCV_dSOC * dOCV_dSOC * Pp00
            - dOCV_dSOC * Pp01
            - dOCV_dSOC * Pp10
            + Pp11
            + EKF_R;

    /* ---- 6. Kalman gain:  K = P*H' / S
     * H' = [dOCV_dSOC; -1]
     * K = [K0; K1]
     */
    float K0 = (dOCV_dSOC * Pp00 - Pp01) / S;
    float K1 = (dOCV_dSOC * Pp10 - Pp11) / S;

    /* ---- 7. State correction ---- */
    state->soc = soc_pred + K0 * innov;
    state->vrc = vrc_pred + K1 * innov;

    /* Clamp corrected SOC */
    if (state->soc > 1.0f) state->soc = 1.0f;
    if (state->soc < 0.0f) state->soc = 0.0f;

    /* ---- 8. Covariance update:  P = (I - K*H) * Pp
     * (I - K*H) = [[1 - K0*dOCV_dSOC,  K0],
     *              [-K1*dOCV_dSOC,      1+K1]]
     */
    state->P[0] = (1.0f - K0 * dOCV_dSOC) * Pp00 + K0 * Pp10;
    state->P[1] = (1.0f - K0 * dOCV_dSOC) * Pp01 + K0 * Pp11;
    state->P[2] = (-K1 * dOCV_dSOC)        * Pp00 + (1.0f + K1) * Pp10;
    state->P[3] = (-K1 * dOCV_dSOC)        * Pp01 + (1.0f + K1) * Pp11;
}
