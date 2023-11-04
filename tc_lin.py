# tc_plots.py
# Plot thermocouple curves

import matplotlib.pyplot as plt
import numpy as np
import thermocouple

tc_type = 'J'
lin_sections = 4

# find tc
tc = None
for t in thermocouple.all_types:
    if t.tc_type == tc_type:
        tc = t
        break
assert tc is not None, f"Could not find coefficients for thermocouple type '{tc_type}'"

print(f"Type-{tc_type}")

# calculate lin_sections linear sections
# we need lin_sections+1 evenly spaced points, including the end points
section_x0 = np.linspace(0, tc.ranges[-1].Emax, lin_sections + 1)
section_y0 = [tc.t90(x0) for x0 in section_x0]
calc_m = lambda x0,y0,x1,y1: (y1 - y0) / (x1 - x0)
# note that section_m has one fewer element than section_x0 and section_y0
section_m  = [calc_m(section_x0[i], section_y0[i], section_x0[i+1], section_y0[i+1]) for i in range(len(section_x0)-1)]

print("mV")
for i in range(len(section_x0)-1):
    print(f"{section_x0[i]: 9.3f}, {section_y0[i]: 9.3f}, {section_m[i]: 9.3f}")
print(f"{section_x0[len(section_x0)-1]: 9.3f}, {section_y0[len(section_x0)-1]: 9.3f}")

fig, (ax1, ax2, ax3) = plt.subplots(nrows=1, ncols=3)

# plot real curve
x = np.linspace(0, tc.ranges[-1].Emax, 1000)
y = [tc.t90(v) for v in x]
ax1.plot(x, y, label="Real")

# plot linear approximate sections
for i in range(len(section_x0)-1):
    x0 = section_x0[i]
    y0 = section_y0[i]
    x1 = section_x0[i+1]
    m = section_m[i]
    x = np.linspace(x0, x1, 10)
    y = y0 + m*(x-x0)
    ax1.plot(x, y, label=f"Section {i+1}")

ax1.set_title(f"Type-{tc_type}")
ax1.set_xlabel("E [mV]")
ax1.set_ylabel("T [C]")
ax1.legend()

# now plot ADC
N = 10 # 10 bit ADC
ADC = lambda E: E * int((2**N-1) / tc.ranges[-1].Emax)
EfromADC = lambda A: A * (tc.ranges[-1].Emax / (2**N-1))
x = range(2**N)
y = [tc.t90(EfromADC(v)) for v in x]
ax2.plot(x, y, label="Real")

section_x0_adc = [int(x) for x in np.linspace(0, 1023, lin_sections + 1)]
section_y0_adc = [tc.t90(EfromADC(x0)) for x0 in section_x0_adc]
section_m_adc  = [calc_m(section_x0_adc[i], section_y0_adc[i], section_x0_adc[i+1], section_y0_adc[i+1]) for i in range(len(section_x0_adc)-1)]

print()
print("ADC")
for i in range(len(section_x0_adc)-1):
    print(f"{section_x0_adc[i]: 5d}, {section_y0_adc[i]: 9.3f}, {section_m_adc[i]: 9.3f}")
print(f"{section_x0_adc[len(section_x0_adc)-1]: 5d}, {section_y0_adc[len(section_x0_adc)-1]: 9.3f}")

# plot linear approximate sections
for i in range(len(section_x0)-1):
    x0 = section_x0_adc[i]
    y0 = section_y0_adc[i]
    x1 = section_x0_adc[i+1]
    m = section_m_adc[i]
    x = np.linspace(x0, x1, 10)
    y = y0 + m*(x-x0)
    ax2.plot(x, y, label=f"Section {i+1}")

ax2.set_title(f"Type-{tc_type} (ADC)")
ax2.set_xlabel("E [mV]")
ax2.set_ylabel("T [C]")
ax2.legend()

# Now reinterpret to fixed point
# centi-C? (two decimal places)

x = range(2**N)
y = [100*tc.t90(EfromADC(v)) for v in x]
ax3.plot(x, y, label="Real")

section_x0_fixed = [int(x) for x in np.linspace(0, 1023, lin_sections + 1)]
section_y0_fixed = [int(100 * tc.t90(EfromADC(x0))) for x0 in section_x0_fixed]
section_m_fixed  = [int(round(calc_m(section_x0_fixed[i], section_y0_fixed[i], section_x0_fixed[i+1], section_y0_fixed[i+1]), 0)) for i in range(len(section_x0_fixed)-1)]

print()
print("ADC (fixed to centi-C)")
for i in range(len(section_x0_fixed)-1):
    print(f"{section_x0_fixed[i]: 5d}, {section_y0_fixed[i]: 7d}, {section_m_fixed[i]: 4d}")
print(f"{section_x0_fixed[len(section_x0_fixed)-1]: 5d}, {section_y0_fixed[len(section_x0_fixed)-1]: 7d}")

# plot linear approximate sections
for i in range(len(section_x0_fixed)-1):
    x0 = section_x0_fixed[i]
    y0 = section_y0_fixed[i]
    x1 = section_x0_fixed[i+1]
    m = section_m_fixed[i]
    x = np.linspace(x0, x1, 10)
    y = y0 + m*(x-x0)
    ax3.plot(x, y, label=f"Section {i+1}")

ax3.set_title(f"Type-{tc_type} (Fixed centi-C)")
ax3.set_xlabel("E [mV]")
ax3.set_ylabel("T [C]")
ax3.legend()

plt.show()
