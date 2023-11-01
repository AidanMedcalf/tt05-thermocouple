// spi_master.v
// SPI master
// CPOL=0 CPHA=0 CE active low

`default_nettype none

module spi_master #(
    parameter integer WORD_SIZE = 16,
    parameter integer WORD_BITS = $clog2(WORD_SIZE)
) (
    // NOTE: all TT IO are synchronous to i_clk
    input                      i_clk,
    input                      i_rst,
    // serial interface
    output reg                 o_sck,
    output reg                 o_sce,
    output reg                 o_sout,
    input                      i_sin,
    // word interface
    input                      i_ena,
    input      [WORD_SIZE-1:0] i_win,
    output reg [WORD_SIZE-1:0] o_wout,
    output reg                 o_wstb
);

    localparam CNT_RST  = WORD_SIZE - 1;
    localparam CNT_BITS = $bits(WORD_SIZE - 1);

    reg running;
    reg [CNT_BITS-1:0] cnt;

    always @(*) begin
        o_sout = i_win[cnt];
        o_sce  = !running;
    end

    always @(posedge i_clk) begin
        o_wstb <= 'b0;
        if (i_rst) begin
            o_wout  <= 'b0;
            running <= 'b0;
            o_sck   <= 'b0;
            cnt     <= CNT_RST;
        end else if (!running && i_ena) begin
            running <= 'b1;
            o_sck   <= 'b0;
            cnt     <= CNT_RST;
        end else if (running) begin
            o_sck   <= !o_sck; // toggle SCK every cycle = divide-by-two
            if (o_sck) begin
                if (cnt == 'b0) begin
                    running <= 'b0;
                    o_wstb  <= 'b1;
                end else
                    cnt <= cnt - 'b1;
            end else begin
                o_wout <= { o_wout[WORD_SIZE-2:0], i_sin };
            end
        end else begin // !running && !i_ena
            o_wout  <= 'b0;
            o_sck   <= 'b0;
            cnt     <= 'b0;
        end
    end

endmodule
