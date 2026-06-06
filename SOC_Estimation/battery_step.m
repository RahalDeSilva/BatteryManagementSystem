function x_next = battery_step(x, I, dt, Q, R0, R1, C1)
    SOC = x(1);
    Vrc = x(2);
    alpha = exp(-dt/(R1*C1));
    beta  = R1*(1 - alpha);
    x_next = [SOC - (I*dt/Q);
    alpha*Vrc + beta*I];
end