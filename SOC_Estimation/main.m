% ========================================================================
% main.m  –  BMS EKF SOC Estimator
%
% Runs the Extended Kalman Filter SOC estimation pipeline on the
% NASA battery dataset (00001.csv).
%
% File dependencies (all must be on MATLAB path):
%   load_data.m     – CSV import and dt extraction
%   battery_step.m  – State transition (RC equivalent circuit)
%   ekf_step.m      – EKF predict + update cycle
%   ocv.m           – OCV lookup with Jacobian output
%
% Usage:
%   Run this script directly from the bms_kalman/ directory.
% ========================================================================

clear; clc; close all;

%% -----------------------------------------------------------------------
%  1. LOAD DATA
% -----------------------------------------------------------------------
data = load_data('data/00001.csv');   % Returns struct: V, I, T, t, dt, N

% NASA dataset convention: negative I = discharge, positive I = charge.
% Our model (battery_step.m, ekf_step.m) assumes SOC(k+1) = SOC(k) - I*dt/Q,
% i.e. positive I = discharge. Flip the sign to match.
data.I = -data.I;
fprintf('Current sign flipped to match model convention. First 5 samples: ');
fprintf('%.4f ', data.I(1:5)); fprintf('\n');


%% -----------------------------------------------------------------------
%  2. BATTERY PARAMETERS
%  Replace these with values identified from your cell characterisation.
% -----------------------------------------------------------------------
Q   = 2.0;       % Rated capacity [Ah] — convert to Coulombs below
Q_C = Q * 3600;  % Capacity in Coulombs [C]

R0  = 0.05;      % Series resistance [Ohm]
R1  = 0.02;      % RC branch resistance [Ohm]
C1  = 2500;      % RC branch capacitance [F]  (tau = R1*C1 = 50 s)

%% -----------------------------------------------------------------------
%  3. EKF NOISE COVARIANCE MATRICES
%
%  Rk: Measurement noise — set from voltage sensor spec (std ~0.02 V)
%  Qk: Process noise    — reflects model uncertainty
%       [0] SOC row: small — coulomb counting model is trustworthy
%       [1] Vrc row: larger — RC parameters have more uncertainty
% -----------------------------------------------------------------------
Rk = 0.02^2;                          % Scalar [V^2]

Qk = [1e-7,   0  ;                    % SOC uncertainty
        0,   1e-5 ];                   % Vrc uncertainty

%% -----------------------------------------------------------------------
%  4. INITIAL CONDITIONS
% -----------------------------------------------------------------------
SOC_init = 1.0;      % Assume fully charged at start
Vrc_init = 0.0;      % No initial RC polarisation

x = [SOC_init; Vrc_init];             % State vector [SOC; Vrc]
P = diag([0.01, 0.01]);               % Initial covariance (low certainty)

%% -----------------------------------------------------------------------
%  5. PRE-ALLOCATE RESULT ARRAYS
% -----------------------------------------------------------------------
SOC_ekf    = zeros(data.N, 1);        % EKF SOC estimate
SOC_cc     = zeros(data.N, 1);        % Coulomb-count-only SOC (benchmark)
V_pred_log = zeros(data.N, 1);        % Predicted terminal voltage

SOC_cc_val = SOC_init;                % Coulomb counter state

%% -----------------------------------------------------------------------
%  6. MAIN EKF LOOP
% -----------------------------------------------------------------------
fprintf('Running EKF over %d samples...\n', data.N);

for k = 1:data.N

    I_k  = data.I(k);
    V_k  = data.V(k);
    dt_k = data.dt(k);

    % -- Coulomb counting only (no correction) --------------------------
    SOC_cc_val  = SOC_cc_val - (I_k * dt_k / Q_C);
    SOC_cc_val  = max(0, min(1, SOC_cc_val));   % Clamp [0,1]
    SOC_cc(k)   = SOC_cc_val;

    % -- EKF predict + update -------------------------------------------
    [x, P] = ekf_step(x, P, I_k, V_k, dt_k, Q_C, R0, R1, C1, Qk, Rk);

    % -- Clamp EKF SOC to physical limits --------------------------------
    x(1) = max(0, min(1, x(1)));

    % -- Log results -----------------------------------------------------
    SOC_ekf(k)    = x(1);
    [V_pred_log(k), ~] = ocv(x(1));
    V_pred_log(k) = V_pred_log(k) - I_k * R0 - x(2);

end

fprintf('EKF complete.\n');

%% -----------------------------------------------------------------------
%  7. PLOT RESULTS
% -----------------------------------------------------------------------
t = data.t;

figure('Name', 'BMS EKF SOC Estimation', 'NumberTitle', 'off');

% --- Plot 1: SOC comparison ---
subplot(3,1,1);
plot(t, SOC_ekf * 100, 'b-',  'LineWidth', 1.5); hold on;
plot(t, SOC_cc  * 100, 'r--', 'LineWidth', 1.2);
xlabel('Time [s]');
ylabel('SOC [%]');
title('SOC Estimation: EKF vs Coulomb Counting');
legend('EKF', 'Coulomb Counting');
grid on;
ylim([0, 110]);

% --- Plot 2: Voltage — measured vs predicted ---
subplot(3,1,2);
plot(t, data.V,      'k-',  'LineWidth', 1.2); hold on;
plot(t, V_pred_log,  'b--', 'LineWidth', 1.2);
xlabel('Time [s]');
ylabel('Voltage [V]');
title('Terminal Voltage: Measured vs EKF Predicted');
legend('Measured', 'EKF Predicted');
grid on;

% --- Plot 3: Voltage residual (innovation) ---
subplot(3,1,3);
residual = data.V - V_pred_log;
plot(t, residual, 'm-', 'LineWidth', 1.0);
xlabel('Time [s]');
ylabel('Residual [V]');
title('Voltage Residual (Measured – Predicted)');
grid on;
yline(0, 'k--');

%% -----------------------------------------------------------------------
%  8. SUMMARY STATISTICS
% -----------------------------------------------------------------------
fprintf('\n--- Summary ---\n');
fprintf('Final EKF SOC      : %.2f %%\n', SOC_ekf(end) * 100);
fprintf('Final CC SOC       : %.2f %%\n', SOC_cc(end)  * 100);
fprintf('Voltage RMSE       : %.4f V\n',  sqrt(mean(residual.^2)));
fprintf('Max |Residual|     : %.4f V\n',  max(abs(residual)));

% ----------------------------------------------------------------
% "Operational" RMSE — excludes the end-of-discharge relaxation
% tail, where current drops to ~0 A and the cell voltage rebounds
% toward OCV. A 1st-order RC model cannot track this multi-timescale
% recovery; this is a documented limitation, not a bug (see README).
% ----------------------------------------------------------------
N_exclude    = 12;
rmse_steady  = sqrt(mean(residual(1:end-N_exclude).^2));
max_steady   = max(abs(residual(1:end-N_exclude)));

fprintf('\n--- Operational (excludes last %d relaxation samples) ---\n', N_exclude);
fprintf('Operational RMSE   : %.4f V\n', rmse_steady);
fprintf('Operational Max    : %.4f V\n', max_steady);