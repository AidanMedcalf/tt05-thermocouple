`default_nettype none

/* I/O MAP
 *     ui_in[0]     SCK        serial clock
 *     ui_in[1]     SCE        serial chip enable
 *     ui_in[2]     SIN        serial in (MOSI)
 *     ui_in[3]     ADC_SIN    ADC serial in (MISO)
 *     ui_in[4]     not used
 *     ui_in[5]     not used
 *     ui_in[6]     not used
 *     ui_in[7]     not used
 *     uo_out[0]    SOUT       serial out (MOSI)
 *     uo_out[1]    ADC_SCK    ADC serial clock
 *     uo_out[2]    ADC_SCE    ADC serial chip enable
 *     uo_out[3]    ADC_SOUT   ADC serial out
 *     uo_out[4]    not used
 *     uo_out[5]    not used
 *     uo_out[6]    not used
 *     uo_out[7]    not used
 *     uio_*[*]     not used
 */

// TODO: serial passthrough to ADC?

module tt_um_thermocouple #(
    parameter WORD_SIZE = 16
) (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // bidirectionals as inputs (do not use)
    assign uio_oe = 8'b00000000;
    assign uio_out = 'b0;
    // TODO: outputs
    assign uo_out[7:4] = 'b0;

    // external clock is 10MHz

    reg [WORD_SIZE-1:0] current_temp;

    reg [WORD_SIZE-1:0] spi_word;
    reg                 spi_stb;

    reg [WORD_SIZE-1:0] adc_word;
    reg                 adc_stb, adc_start;

    reg                 calc_done;

    // SPI master - read from adc
    spi_master #(.WORD_SIZE(WORD_SIZE)) spi_master (
        .i_clk(clk), .i_rst(!rst_n || !ena),
        .o_sck(uo_out[1]), .o_sce(uo_out[2]), .o_sout(uo_out[3]), .i_sin(ui_in[3]),
        .i_ena(adc_start), .i_win(16'b0), .o_wout(adc_word), .o_wstb(adc_stb)
    );

    // SPI slave
    spi_slave #(.WORD_SIZE(WORD_SIZE)) spi_slave (
        .i_clk(clk), .i_rst(!rst_n || !ena),
        .i_sck(ui_in[0]), .i_sce(ui_in[1]), .i_sin(ui_in[2]), .o_sout(uo_out[0]),
        .i_win(current_temp), .o_wout(spi_word), .o_wstb(spi_stb)
    );

    // calculator
    tc_calc tc_calc (
        .i_clk(clk), .i_rst(!rst_n || !ena),
        .i_start(adc_stb), .i_code(adc_word[9:0]),
        .o_temp(current_temp), .o_done(calc_done)
    );

    // state machine: read from ADC, calculate, store
    localparam [0:0] READ = 1'b0,
                     CALC = 1'b1;
    reg state;

    always @(posedge clk) begin
        adc_start <= 'b0;
        if (!rst_n || !ena) begin
            state <= READ;
        end else begin
            case (state)
                READ: begin
                    state     <= CALC;
                    adc_start <= 'b1;
                end
                CALC: begin
                    if (calc_done) begin
                        state <= READ;
                    end
                end
                default: begin
                    state     <= 1'bx;
                    adc_start <= 1'bx;
                end
            endcase
        end
    end

endmodule
