// spi_slave.v
// SPI slave
// CPOL=0 CPHA=0 CE active low

`default_nettype none

module spi_slave #(
    parameter integer WORD_SIZE = 16,
    parameter integer WORD_BITS = $clog2(WORD_SIZE)
) (
    // NOTE: all TT IO are synchronous to i_clk
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

    // serial clock
    reg                  sck_dly;
    wire                 sck_pe, sck_ne;
    // bit counter
    reg  [WORD_BITS-1:0] cnt;     // SPI bit counter

    // serial clock
    assign sck_pe =  i_sck && !sck_dly;
    assign sck_ne = !i_sck &&  sck_dly;
    always @(posedge i_clk)
        if (i_rst) sck_dly <= 'b0;
        else       sck_dly <= i_sck;

    // counter
    localparam [WORD_BITS:0] cnt_rst_val = WORD_SIZE - 1;
    assign o_wstb = cnt == 'b0;
    always @(posedge i_clk)
        if (i_rst || i_sce || o_wstb) cnt <= cnt_rst_val[WORD_BITS-1:0];
        else if (sck_ne)              cnt <= cnt - 'b1;

    // serial out
    assign o_sout = i_win[cnt];

    // serial in
    always @(posedge i_clk)
        if (i_rst)                 o_wout <= 'b0;
        else if (sck_pe && !i_sce) o_wout <= { i_sin, o_wout[WORD_SIZE-1:1] };

endmodule
