#include <stdio.h>
#include <stdint.h>
#include "ekf.h"
#include "nasa_data.h"

static float soc_log[NASA_SAMPLE_COUNT];

int main(void)
{
    EKF_State ekf;
    EKF_Init(&ekf, 1.0f);

    printf("Sample, Time_s, Voltage_V, Current_A, SOC_EKF\n");

    for (uint16_t i = 0; i < NASA_SAMPLE_COUNT; i++)
    {
        float V  = nasa_voltage[i];
        float I  = nasa_current[i];
        float dt = nasa_dt[i];

        if (i == 0) {
            soc_log[i] = ekf.soc;
            printf("%3d, %8.2f, %.4f, %.4f, %.4f\n",
                   i, 0.0f, V, I, ekf.soc);
            continue;
        }

        EKF_Update(&ekf, I, V, dt);
        soc_log[i] = ekf.soc;

        /* Print every 10th sample to keep output readable */
        if (i % 10 == 0) {
            /* Reconstruct time from nasa_data */
            printf("%3d, %8.2f, %.4f, %.4f, %.4f\n",
                   i, (float)i * 13.0f, V, I, ekf.soc);
        }
    }

    printf("\nFinal SOC: %.4f (%.1f%%)\n",
           soc_log[NASA_SAMPLE_COUNT - 1],
           soc_log[NASA_SAMPLE_COUNT - 1] * 100.0f);

    return 0;
}
