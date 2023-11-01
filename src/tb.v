`default_nettype none
`timescale 1ns/1ps

/*
this testbench just instantiates the module and makes some convenient wires
that can be driven / tested by the cocotb test.py
*/

// testbench is controlled by test.py
module tb (
    // system
    input   clk,
    input   rst_n,
    input   ena,
    // spi
    input   spi_sck,
    input   spi_sce,
    input   spi_sin,
    output  spi_sout,
    // adc spi
    output  adc_sck,
    output  adc_sce,
    input   adc_sin,
    output  adc_sout
);

    // this part dumps the trace to a vcd file that can be viewed with GTKWave
    initial begin
        $dumpfile ("tb.vcd");
        $dumpvars (0, tb);
        `ifndef VERILATOR
            #1;
        `endif
    end

    // assign spi_sce   = uio_in[0]  && !uio_oe[0];
    // assign spi_sin   = uio_in[1]  && !uio_oe[1];
    // assign spi_sck   = uio_in[3]  && !uio_oe[3];
    // assign adc_sin   = uio_in[6]  && !uio_oe[6];

    assign uio_in[0] = uio_oe[0] ? uio_out[0] : spi_sce;
    assign uio_in[1] = uio_oe[1] ? uio_out[1] : spi_sin;
    assign spi_sout  = uio_oe[2] ? uio_out[2] : uio_in[2];
    assign uio_in[3] = uio_oe[3] ? uio_out[3] : spi_sck;
    assign adc_sce   = uio_oe[4] ? uio_out[4] : uio_in[4];
    assign adc_sout  = uio_oe[5] ? uio_out[5] : uio_in[5];
    assign uio_in[6] = uio_oe[6] ? uio_out[6] : adc_sin;
    assign adc_sck   = uio_oe[7] ? uio_out[7] : uio_in[7];

    wire [7:0] ui_in = 8'b0;
    wire [7:0] uo_out;
    wire [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    assign { uio_in[7], uio_in[5:4], uio_in[2] } = 'b0;

    tt_um_thermocouple tt_um_thermocouple (
    // include power ports for the Gate Level test
    `ifdef GL_TEST
        .VPWR( 1'b1),
        .VGND( 1'b0),
    `endif
        .ui_in      (ui_in),    // Dedicated inputs
        .uo_out     (uo_out),   // Dedicated outputs
        .uio_in     (uio_in),   // IOs: Input path
        .uio_out    (uio_out),  // IOs: Output path
        .uio_oe     (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
        .ena        (ena),      // enable - goes high when design is selected
        .clk        (clk),      // clock
        .rst_n      (rst_n)     // not reset
    );

endmodule
