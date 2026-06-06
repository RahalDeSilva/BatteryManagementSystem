function [x_new, P_new] = ekf_step(x, P, I, V_meas, dt, Qb, R0, R1, C1, Qk, Rk)
    alpha = exp(-dt/(R1*C1));
    beta  = R1*(1 - alpha);
    
    % Predict
    x_pred = [x(1) - I*dt/Qb;
    alpha*x(2) + beta*I];
    A = [1, 0; 0, alpha];
    P_pred = A*P*A' + Qk;
    
    % Update
    V_pred = ocv(x_pred(1)) - I*R0 - x_pred(2);
    H = [1.2, -1];   % Replace 1.2 with dOCV/dSOC when non-linear
    S = H*P_pred*H' + Rk;
    K = P_pred*H' / S;
    x_new = x_pred + K*(V_meas - V_pred);
    P_new = (eye(2) - K*H)*P_pred;
end