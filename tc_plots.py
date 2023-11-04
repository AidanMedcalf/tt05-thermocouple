# tc_plots.py
# Plot thermocouple curves

import matplotlib.pyplot as plt
import numpy as np
import thermocouple

print(f"Thermocouple types: {' '.join([t.tc_type for t in thermocouple.all_types])}")

for tc in thermocouple.all_types:
    xmin = tc.ranges[0].Emin
    xmax = tc.ranges[-1].Emax
    x = np.linspace(xmin, xmax, 1000)
    y = [tc.t90(v) for v in x]
    plt.plot(x, y, label=f"Type-{tc.tc_type}")

plt.legend()
plt.show()
