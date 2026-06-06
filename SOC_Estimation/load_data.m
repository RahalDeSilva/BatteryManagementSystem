function data = load_data(filepath)
% LOAD_DATA  Import NASA battery CSV and compute variable timesteps.
%
%   data = load_data(filepath)
%
%   Returns a struct with fields:
%     data.V      - measured terminal voltage [V]        (Nx1)
%     data.I      - measured current [A]                 (Nx1)
%     data.T      - temperature [deg C]                  (Nx1)
%     data.t      - time vector [s]                      (Nx1)
%     data.dt     - variable timestep vector [s]         (Nx1)
%     data.N      - number of samples
%
%   Expected CSV columns (from NASA dataset 00001.csv):
%     Voltage_measured, Current_measured, Temperature_measured,
%     Current_load, Voltage_load, Time

    % ----------------------------------------------------------------
    % 1. Read the CSV
    % ----------------------------------------------------------------
    raw = readtable(filepath);

    % ----------------------------------------------------------------
    % 2. Extract relevant columns
    % ----------------------------------------------------------------
    data.V = raw.Voltage_measured;       % Terminal voltage [V]
    data.I = raw.Current_measured;       % Current [A] (negative = discharge)
    data.T = raw.Temperature_measured;   % Temperature [deg C]
    data.t = raw.Time;                   % Time [s]
    data.N = length(data.t);

    % ----------------------------------------------------------------
    % 3. Compute variable timestep dt
    %    dt(1) is set to the first interval; thereafter diff(t)
    %    This avoids the EKF receiving a zero timestep on sample 1.
    % ----------------------------------------------------------------
    dt_raw       = diff(data.t);         % (N-1) x 1
    data.dt      = [dt_raw(1); dt_raw];  % Pad to N x 1 using first interval

    % ----------------------------------------------------------------
    % 4. Sanity checks
    % ----------------------------------------------------------------
    if any(data.dt <= 0)
        warning('load_data: non-positive timesteps detected. Check Time column.');
    end

    if any(isnan(data.V)) || any(isnan(data.I))
        warning('load_data: NaN values found in voltage or current. Check dataset.');
    end

    fprintf('load_data: loaded %d samples | dt range [%.3f, %.3f] s\n', ...
        data.N, min(data.dt), max(data.dt));
end
