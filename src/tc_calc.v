// tc_calc.v
// Calculate thermocouple temperature from ADC counts

`default_nettype none

// currently: type K only
// assuming a 10-bit ADC from 0 to ~56mV, i.e. 0C to 1379C
// 8 linear approximate sections:
// 1 determine section
// 2 linearly interpolate

module tc_calc (
    input  i_clk,
    input  i_rst,

    input             i_start,
    input       [9:0] i_code,
    output reg [19:0] o_temp,
    output reg        o_done
);

    // 10 bits / 4 sections = top two bits are section, bottom 8 are value:
    // code = 10'bSSVVVVVVVV
    reg [1:0] cs;
    reg [7:0] cv;

    /*
     *     0,       0,  132
     *   255,   33536,  127
     *   511,   65924,  132
     *   767,   99678,  147
     *  1023,  137204
     */

    // interpolation coefficient ROM
    // slope
    wire [19:0] crom_slope [4];
    assign crom_slope[0] = 20'd132;
    assign crom_slope[1] = 20'd127;
    assign crom_slope[2] = 20'd132;
    assign crom_slope[3] = 20'd147;
    // intercept
    wire [19:0] crom_intercept [4];
    assign crom_intercept[0] = 20'd0;
    assign crom_intercept[1] = 20'd33536;
    assign crom_intercept[2] = 20'd65924;
    assign crom_intercept[3] = 20'd99678;

    localparam [1:0] IDLE = 2'b00,
                     LOAD = 2'b01,
                     CALC = 2'b10;
    reg [1:0] state;

    reg [19:0] active_slope;
    reg [19:0] active_intercept;
    always @(posedge i_clk) begin
        o_done <= 'b0;
        if (i_rst) begin
            state            <= IDLE;
            active_slope     <= 'b0;
            active_intercept <= 'b0;
            cs               <= 'b0;
            cv               <= 'b0;
            o_temp           <= 'b0;
        end else case (state)
            IDLE: begin
                if (i_start) begin
                    state      <= LOAD;
                    { cs, cv } <= i_code;
                end
            end
            LOAD: begin
                state  <= CALC;
                active_slope     <= crom_slope[cs];
                active_intercept <= crom_intercept[cs];
            end
            CALC: begin
                state  <= IDLE;
                o_temp <= active_intercept + active_slope * {12'b0, cv};
                o_done <= 'b1;
            end
            default: begin
                o_done <= 1'bx;
            end
        endcase
    end

endmodule
