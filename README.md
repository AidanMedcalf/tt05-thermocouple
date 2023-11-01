![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg)

# TT05 Thermocouple-to-Temperature Converter

Converts 10-bit thermocouple ADC counts into temperature by approximating the transfer function with
piecewise linear segments and interpolating.

* Interface: SPI (16-bit word)
* ADC interface: SPI (16-bit word, 10 bits used)
* Output: Temperature in celsius, 16-bit over full positive range of thermocouple type

ADC range: 0 counts = 0 mV = 0 C, max counts (1023) = max mV = max C. Example: For type-K
thermocouple, 1023 counts = 54.886 mV = 1372 C

Current limitations:
* Only type-K thermocouple
* Only positive temperatures
* Only 10-bit ADC
* No ADC passthrough (for e.g. configuration)
