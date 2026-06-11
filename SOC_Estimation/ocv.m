function [V_ocv, dOCV_dSOC] = ocv(soc)
% OCV  Open-circuit voltage lookup for a lithium-ion cell.
%
%   [V_ocv, dOCV_dSOC] = ocv(soc)
%
%   Inputs:
%     soc       - State of Charge, scalar in [0, 1]
%
%   Outputs:
%     V_ocv     - Open-circuit voltage [V]
%     dOCV_dSOC - Gradient of OCV w.r.t. SOC (for EKF Jacobian H)
%
%   Implementation:
%     Piecewise-linear interpolation over a characterisation table.
%     Replace the soc_lut / ocv_lut vectors below with values extracted
%     from your own cell characterisation (slow discharge OCV test).
%
%   NOTE: The original linear approximation (3.0 + 1.2*SOC) is retained
%   as a comment for reference only — do NOT use it with real data.

    % ----------------------------------------------------------------
    % OCV lookup table (SOC vs Voltage)
    %
    % Range extended to cover the measured voltage span of the
    % NASA 00001.csv dataset: V_measured in [2.471, 4.247] V.
    % A small margin is added on both ends (2.40 V and 4.30 V) so the
    % EKF never sits exactly at the table boundary during normal noise.
    %
    % NOTE: These are still generic 18650 values. For best accuracy,
    % replace with values extracted from your own characterisation:
    %   1. Extract a very-low-current (quasi-static) discharge segment
    %   2. Plot V_measured vs cumulative Ah / rated Ah
    %   3. Read off (SOC, V) pairs at 5-10% SOC intervals
    % ----------------------------------------------------------------
    soc_lut = [0.00, 0.02, 0.05, 0.10, 0.20, 0.30, 0.40, 0.50, ...
               0.60, 0.70, 0.80, 0.90, 0.95, 0.98, 1.00];

    ocv_lut = [2.40, 2.55, 2.80, 3.05, 3.40, 3.58, 3.69, 3.78, ...
               3.84, 3.89, 3.95, 4.03, 4.10, 4.20, 4.30];

    % ----------------------------------------------------------------
    % Clamp SOC to valid range to avoid extrapolation
    % ----------------------------------------------------------------
    soc_clamped = max(0.0, min(1.0, soc));

    if soc ~= soc_clamped
        warning('ocv: SOC = %.4f clamped to [0, 1].', soc);
    end

    % ----------------------------------------------------------------
    % Linear interpolation for OCV value
    % ----------------------------------------------------------------
    V_ocv = interp1(soc_lut, ocv_lut, soc_clamped, 'linear');

    % ----------------------------------------------------------------
    % Numerical gradient for EKF Jacobian (dOCV/dSOC)
    %   Used in H = [dOCV_dSOC, -1] inside ekf_step.m
    %   Central difference with small delta
    % ----------------------------------------------------------------
    delta = 1e-4;
    soc_hi = min(soc_clamped + delta, 1.0);
    soc_lo = max(soc_clamped - delta, 0.0);

    V_hi = interp1(soc_lut, ocv_lut, soc_hi, 'linear');
    V_lo = interp1(soc_lut, ocv_lut, soc_lo, 'linear');

    dOCV_dSOC = (V_hi - V_lo) / (soc_hi - soc_lo);

    % ----------------------------------------------------------------
    % Original linear placeholder (DO NOT USE with real data):
    %   V_ocv     = 3.0 + 1.2 * soc;
    %   dOCV_dSOC = 1.2;
    % ----------------------------------------------------------------
end