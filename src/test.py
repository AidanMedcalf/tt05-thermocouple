import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles, First
from random import random

def log_null(*args, **kwargs):
    pass

class spi_bus:
    def __init__(self, sck, sce, mosi, miso):
        self.sck = sck
        self.sce = sce
        self.mosi = mosi
        self.miso = miso
    
    def __str__(self) -> str:
        return f"SPI bus sck={self.sck} sce={self.sce} mosi={self.mosi} miso={self.miso}"

async def setup_dut(dut):
    dut._log.info("start")
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())

    # initialize inputs
    dut.spi_sck.value = 0
    dut.spi_sce.value = 1
    dut.spi_sin.value = 0
    dut.adc_sin.value = 0

    spi = spi_bus(dut.spi_sck, dut.spi_sce, dut.spi_sin, dut.spi_sout)
    adc_spi = spi_bus(dut.adc_sck, dut.adc_sce, dut.adc_sout, dut.adc_sin)

    # reset
    dut._log.info("reset")
    dut.rst_n.value = 0
    dut.ena.value = 1
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    return spi, adc_spi

async def spi_slave_fixed_task(spi: spi_bus, data: int, log=log_null):
    log(f"[spi_slave_fixed_task] Start with {spi} data = {data}")
    while True:
        if spi.sce.value:
            #log(f"[spi_slave_fixed_task] wait for SCE low")
            await FallingEdge(spi.sce)
        #log(f"[spi_slave_fixed_task] SCE low START")
        # shift out data
        # cpol=0 cpha=0, msb first
        for i in range(16):
            # set bit
            #log(f"[spi_slave_fixed_task] Bit {15 - i} = {(data >> (15 - i)) & 1}")
            spi.miso.value = (data >> (15 - i)) & 1
            #log(f"[spi_slave_fixed_task] bit {i} = {spi.miso.value}")
            #log("[spi_slave_fixed_task] wait for \spi.sck | /spi.sce")
            # wait for next falling edge, but abort on sce rising edge
            await First(FallingEdge(spi.sck), RisingEdge(spi.sce))
            await Timer(1, 'ns')
            # if sce went high, abort this transfer
            if i == 15:
                #log(f"[spi_slave_fixed_task] Finished transfer STOP")
                pass
            elif spi.sce.value:
                #log(f"[spi_slave_fixed_task] SCE high STOP")
                break
            else:
                pass
                #log("[spi_slave_fixed_task] CONTINUE")

        await Timer(1, units="ns")

async def with_delay(coro: cocotb.Task or cocotb.Coroutine, delay, units: str = "step"):
    await Timer(delay, units)
    return await coro

def sim_period(freq: float):
    return (10*int(100000.0/freq))/1000.0 # freq (MHz) -> period (ns), rounded to 10ps

async def spi_master_read(spi: spi_bus, ref_clk, bits=16, freq=1, toff=0, log=log_null):
    log(f"[spi_master_read] Start with {spi}")
    # initialize values
    spi.sce.value = 0
    spi.mosi.value = 0
    spi.sck.value = 0
    data = 0
    # start clock
    period = sim_period(freq)
    units = 'ns'
    delay = int(1 + period + toff) # round to 1 ns
    #log(f"{period=}, {toff=}, {delay=}")
    sck_task = cocotb.start_soon(with_delay(Clock(spi.sck, period, units=units).start(), delay, 'ns'))
    # shift bits
    for i in range(bits):
        await RisingEdge(spi.sck)
        data = (data << 1) | spi.miso.value
    # wait and kill clock
    await Timer(period, 'ns')
    sck_task.kill()
    # done!
    spi.sce.value = 1
    await Timer(1, 'ns')
    log(f"[spi_master_read] Finished transfer, read {data}")
    return data

@cocotb.test()
async def test_temp_read(dut):
    """Test temp read"""

    spi, adc_spi = await setup_dut(dut)

    # start adc spi fixed temperature task
    adc_code = 0x0150 # 18mv = ~450C = 336 adc counts = 0x0150
    adc_task = cocotb.start_soon(spi_slave_fixed_task(adc_spi, adc_code, log=dut._log.info))

    # ~36 clock cycles to read from ADC
    await ClockCycles(dut.clk, 50)

    # now read value back
    data = await spi_master_read(spi, dut.clk, log=dut._log.info)
    # adc_code is in section 1, so temp = (33536 + 127*(adc_code - 0x0100))/4 = (33536 + 127*80)/4 = 43696/4 = 10924
    # Note: 43696 = 436.96 deg C
    assert data == 10924 # 0x2AAC

    adc_task.kill()
    await ClockCycles(dut.clk, 2)

@cocotb.test()
async def test_phase(dut):
    """Test device read with random SCK/CLK phase"""

    spi, adc_spi = await setup_dut(dut)

    # start adc spi fixed temperature task
    adc_code = 0x0150 # 18mv = ~450C = 336 adc counts = 0x0150
    adc_task = cocotb.start_soon(spi_slave_fixed_task(adc_spi, adc_code, log=dut._log.info))

    # ~36 clock cycles to read from ADC
    await ClockCycles(dut.clk, 50)

    N = 100
    for i in range(N):
        # clk period is 100ns, sck period is 1000ns, so pick toff in [0, 100]ns
        toff = 100.0 * random()
        # now read value back
        data = await spi_master_read(spi, dut.clk, toff=toff, log=dut._log.info)
        # adc_code is in section 1, so temp = (33536 + 127*(adc_code - 0x0100))/4 = (33536 + 127*80)/4 = 43696/4 = 10924
        # Note: 43696 = 436.96 deg C
        assert data == 10924 # 0x2AAC
        await Timer(1, 'us')

    adc_task.kill()
    await ClockCycles(dut.clk, 2)
