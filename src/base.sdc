read_sdc $::env(OPENLANE_ROOT)/scripts/base.sdc

# uio[0]    SCE                async
# uio[1]    SIN  (MOSI)        async
# uio[2]    SOUT (MISO)        async
# uio[3]    SCK                async
# uio[4]    ADC_SCE            sync to clk
# uio[5]    ADC_SIN (MISO)     async
# uio[6]    ADC_SOUT (MOSI)    sync to clk
# uio[7]    ADC_SCK            sync to clk

# SCE
set_false_path -from [get_ports uio_in\[0\]]
# SIN
set_false_path -from [get_ports uio_in\[1\]]
# SOUT
set_false_path -to   [get_ports uio_out\[2\]]
# SCK
set_false_path -from [get_ports uio_in\[3\]]
# ADC_SIN
set_false_path -from [get_ports uio_in\[5\]]
