// tc_calc.v
// Calculate thermocouple temperature from ADC counts

`default_nettype none

// Example: Type-K
// assuming a 10-bit ADC from 0 to ~56mV, i.e. 0C to 1379C
// 4 linear approximate sections:
// 1. determine section
// 2. linearly interpolate

module tc_calc (
    input  i_clk,
    input  i_rst,

    input             i_start,
    input       [9:0] i_code,
    input       [0:0] i_type,
    output reg [19:0] o_temp,
    output reg        o_done
);

    // 10 bits / 4 sections = top two bits are section, bottom 8 are value:
    // code = 10'bSSVVVVVVVV
    reg [1:0] cs;
    reg [7:0] cv;

    /* Type-J
     *     0,       0,  125
     *   255,   31825,  121
     *   511,   62783,  108
     *   767,   90432,  115
     *  1023,  119996
     */

    /* Type-K
     *     0,       0,  132
     *   255,   33536,  127
     *   511,   65924,  132
     *   767,   99678,  147
     *  1023,  137204
     */

    // interpolation coefficient ROM
    // 0 Type-J
    // slope
    wire [19:0] crom_slope_0 [4];
    assign crom_slope_0[0] = 20'd125;
    assign crom_slope_0[1] = 20'd121;
    assign crom_slope_0[2] = 20'd108;
    assign crom_slope_0[3] = 20'd115;
    // intercept
    wire [19:0] crom_intercept_0 [4];
    assign crom_intercept_0[0] = 20'd0;
    assign crom_intercept_0[1] = 20'd31825;
    assign crom_intercept_0[2] = 20'd62783;
    assign crom_intercept_0[3] = 20'd90432;
    // 1 Type-K
    // slope
    wire [19:0] crom_slope_1 [4];
    assign crom_slope_1[0] = 20'd132;
    assign crom_slope_1[1] = 20'd127;
    assign crom_slope_1[2] = 20'd132;
    assign crom_slope_1[3] = 20'd147;
    // intercept
    wire [19:0] crom_intercept_1 [4];
    assign crom_intercept_1[0] = 20'd0;
    assign crom_intercept_1[1] = 20'd33536;
    assign crom_intercept_1[2] = 20'd65924;
    assign crom_intercept_1[3] = 20'd99678;

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
                case (i_type)
                    1'b0: begin // Type-J
                        active_slope     <= crom_slope_0[cs];
                        active_intercept <= crom_intercept_0[cs];
                    end
                    1'b1: begin // Type-K
                        active_slope     <= crom_slope_1[cs];
                        active_intercept <= crom_intercept_1[cs];
                    end
                    default: begin
                        active_slope     <= 20'bx;
                        active_intercept <= 20'bx;
                    end
                endcase
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
