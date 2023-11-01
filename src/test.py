import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles, First

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
    clock = Clock(dut.clk, 10, units="us")
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
            await FallingEdge(spi.sce)
        log(f"[spi_slave_fixed_task] SCE low")
        # shift out data
        # cpol=0 cpha=0, msb first
        for i in range(16):
            # set bit
            #log(f"[spi_slave_fixed_task] Bit {15 - i} = {(data >> (15 - i)) & 1}")
            spi.miso.value = (data >> (15 - i)) & 1
            # wait for next falling edge, but abort on sce rising edge
            await First(FallingEdge(spi.sck), RisingEdge(spi.sce))
            # if sce went high, abort this transfer
            if spi.sce.value:
                log(f"[spi_slave_fixed_task] SCE high, aborting")
                break
        log(f"[spi_slave_fixed_task] Finished transfer")
        await Timer(1, units="us")

async def spi_master_read(spi: spi_bus, ref_clk, divider=4, bits=16, log=log_null):
    log(f"[spi_master_read] Start with {spi}")
    spi.sce.value = 0
    spi.mosi.value = 0
    spi.sck.value = 0
    data = 0
    for i in range(bits):
        await ClockCycles(ref_clk, divider)
        data = (data << 1) | spi.miso.value
        spi.sck.value = 1
        await ClockCycles(ref_clk, divider)
        spi.sck.value = 0
    spi.sce.value = 1
    log(f"[spi_master_read] Finished transfer, read {data}")
    return data

@cocotb.test()
async def test_temp_read(dut):
    spi, adc_spi = await setup_dut(dut)

    # start adc spi fixed temperature task
    adc_code = 0x0150 # 18mv = ~450C = 336 adc counts = 0x0150
    adc_task = cocotb.start_soon(spi_slave_fixed_task(adc_spi, adc_code, log=dut._log.info))

    # ~36 clock cycles to read from ADC
    await ClockCycles(dut.clk, 40)

    # now read value back
    data = await spi_master_read(spi, dut.clk, divider=2, log=dut._log.info)
    # adc_code is in section 1, so temp = 100 + 100*(adc_code - 0x0100) = 100 + 100*80 = 8100
    # TODO: fix this when we have real values
    assert data == 0x1FA4

    adc_task.kill()
    await ClockCycles(dut.clk, 2)
