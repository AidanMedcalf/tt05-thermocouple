`default_nettype none

/* I/O MAP (chosen to match dual SPI PMOD)
 *     ui_in[7:0]   not used
 *     uo_out[7:0]  not used
 *     uio[0]       SCE         input     serial chip enable
 *     uio[1]       SIN         input     serial in (MOSI)
 *     uio[2]       SOUT        output    serial out (MISO)
 *     uio[3]       SCK         input     serial clock
 *     uio[4]       ADC_SCE     output    ADC serial chip enable
 *     uio[5]       ADC_SOUT    output    ADC serial out (MOSI)
 *     uio[6]       ADC_SIN     input     ADC serial in (MISO)
 *     uio[7]       ADC_SCK     output    ADC serial clock
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

    // bidirectional output enable
    assign uio_oe = 8'b10110100;
    assign { uio_out[6], uio_out[3], uio_out[1:0] } = 'b0;

    // dedicated outputs to zero
    assign uo_out = 'b0;

    // external clock is 10MHz

    // redirect IO on passthrough
    wire io_adc_passthrough;

    // i/o assignment
    wire spi_sce, spi_sin, spi_sout, spi_sck, adc_sce, adc_sout, adc_sin, adc_sck;
    assign spi_sce    = uio_in[0];
    assign spi_sin    = uio_in[1];
    assign uio_out[2] = io_adc_passthrough ? adc_sin : spi_sout;
    assign spi_sck    = uio_in[3];
    assign uio_out[4] = io_adc_passthrough ? spi_sce : adc_sce;
    assign uio_out[5] = io_adc_passthrough ? spi_sin : adc_sout;
    assign adc_sin    = uio_in[6];
    assign uio_out[7] = io_adc_passthrough ? spi_sck : adc_sck;

    // temperature
    reg           [19:0] current_temp;
    wire          [19:0] shift_temp = current_temp >> 2;
    wire [WORD_SIZE-1:0] out_temp = shift_temp[WORD_SIZE-1:0];

    // spi signals
    reg  [WORD_SIZE-1:0] spi_word;
    reg                  spi_stb;
    reg  [WORD_SIZE-1:0] adc_word;
    reg                  adc_stb, adc_start;

    // internal signals
    reg                  calc_done;
    localparam CFG_BITS = 2;
    reg   [CFG_BITS-1:0] cfg;
    wire                 cfg_adc_passthrough = cfg[0];
    wire           [0:0] cfg_tc_type         = cfg[1:1];
    wire                 read_ena = !cfg_adc_passthrough;
    assign io_adc_passthrough = cfg_adc_passthrough;

    // SPI master - read from adc
    spi_master #(.WORD_SIZE(WORD_SIZE)) spi_master (
        .i_clk(clk), .i_rst(!rst_n || !ena),
        .o_sck(adc_sck), .o_sce(adc_sce), .o_sout(adc_sout), .i_sin(adc_sin),
        .i_ena(adc_start), .i_win(16'b0), .o_wout(adc_word), .o_wstb(adc_stb)
    );

    // SPI slave
    spi_slave #(.WORD_SIZE(WORD_SIZE)) spi_slave (
        .i_clk(clk), .i_rst(!rst_n || !ena),
        .i_sck(spi_sck), .i_sce(spi_sce), .i_sin(spi_sin), .o_sout(spi_sout),
        .i_win(out_temp), .o_wout(spi_word), .o_wstb(spi_stb)
    );

    // calculator
    tc_calc tc_calc (
        .i_clk(clk), .i_rst(!rst_n || !ena),
        .i_start(adc_stb), .i_code(adc_word[9:0]), .i_type(cfg_tc_type),
        .o_temp(current_temp), .o_done(calc_done)
    );

    // state machine: read from ADC, calculate, store
    localparam [0:0] READ = 1'b0,
                     CALC = 1'b1;
    reg state;
    always @(posedge clk) begin
        adc_start <= 'b0;
        if (!rst_n || !ena || !read_ena) begin
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

    // configuration
    always @(posedge clk) begin
        if (!rst_n) begin
            cfg <= 'b0;
        end else if (spi_stb) begin
            // if write
            if (spi_word[WORD_SIZE-1]) begin
                cfg <= spi_word[CFG_BITS-1:0];
            end
        end
    end

endmodule
