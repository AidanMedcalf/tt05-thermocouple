// spi_slave.v
// SPI slave
// CPOL=0 CPHA=0 CE active low

`default_nettype none

module spi_slave #(
    parameter integer WORD_SIZE = 16,
    parameter integer WORD_BITS = $clog2(WORD_SIZE)
) (
    input                      i_clk,
    input                      i_rst,
    // serial interface
    input                      i_sck,
    input                      i_sce,
    input                      i_sin,
    output                     o_sout,
    // word interface
    input      [WORD_SIZE-1:0] i_win,
    output reg [WORD_SIZE-1:0] o_wout,
    output                     o_wstb
);

    // sync sck
    reg [2:0] sck_sync;
    //wire      sck    = sck_sync[1];
    wire      sck_pe =  sck_sync[1] && !sck_sync[2];
    wire      sck_ne = !sck_sync[1] &&  sck_sync[2];
    always @(posedge i_clk)
        if (i_rst) sck_sync <= 3'b0;
        else       sck_sync <= { sck_sync[1:0], i_sck };

    // sync sce
    reg [1:0] sce_sync;
    wire      sce    = sce_sync[1];
    //wire      sce_pe =  sce_sync[1] && !sce_sync[2];
    //wire      sce_ne = !sce_sync[1] &&  sce_sync[2];
    always @(posedge i_clk)
        if (i_rst) sce_sync <= 2'b0;
        else       sce_sync <= { sce_sync[0:0], i_sce };

    // bit counter
    reg  [WORD_BITS-1:0] cnt;     // SPI bit counter

    // counter
    localparam WORD_SIZE_LESS_ONE = WORD_SIZE - 1;
    localparam [WORD_BITS-1:0] cnt_rst_val = WORD_SIZE_LESS_ONE[WORD_BITS-1:0]; // make verilator happy
    wire last_cycle = cnt == 'b0;
    assign o_wstb = last_cycle && sck_ne;
    always @(posedge i_clk)
        if (i_rst || sce || o_wstb) cnt <= cnt_rst_val[WORD_BITS-1:0];
        else if (sck_ne)            cnt <= cnt - 'b1;

    // serial out
    assign o_sout = i_win[cnt];

    // serial in
    always @(posedge i_clk)
        if (i_rst)               o_wout <= 'b0;
        else if (sck_pe && !sce) o_wout <= { o_wout[WORD_SIZE-2:0], i_sin };

endmodule
