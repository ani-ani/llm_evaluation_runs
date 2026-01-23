module rain_cycler #(
    parameter T = 16,
    parameter DATA_WIDTH = 24,
    parameter RAIN_WIDTH = 8
)(
    input clk,
    input rst_n,
    input start,
    input [DATA_WIDTH-1:0] c,
    input [DATA_WIDTH-1:0] d,
    input [RAIN_WIDTH-1:0] rain [0:15],
    output reg [DATA_WIDTH-1:0] result,
    output reg done
);

    localparam RAIN_SUM_WIDTH = RAIN_WIDTH + 4; // RAIN_WIDTH + $clog2(T), T=16 (4 bits)
    localparam [2:0]
        IDLE        = 3'd0,
        CUMULATIVE  = 3'd1,
        PRE_SWEAT   = 3'd2,
        LOOP_DT     = 3'd3,
        DONE_ST     = 3'd4;

    reg [2:0] state, next_state;
    reg [4:0] cum_index;
    reg [RAIN_SUM_WIDTH-1:0] rain_cum [0:16]; // T=16 maximum
    reg [4:0] dt_counter;
    reg [83:0] numerator_reg;
    reg [DATA_WIDTH-1:0] min_wetness;
    integer i; // For loops in reset
    reg [7:0] cycle_counter; // Backup timeout

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= {DATA_WIDTH{1'b0}};
            min_wetness <= {DATA_WIDTH{1'b1}}; // High initial value
            dt_counter <= 5'd0;
            cum_index <= 5'd0;
            numerator_reg <= 84'd0;
            cycle_counter <= 8'd0;

            // Initialize rain_cum array
            for (i = 0; i <= T; i = i + 1) begin
                rain_cum[i] <= {RAIN_SUM_WIDTH{1'b0}};
            end
        end else begin
            cycle_counter <= cycle_counter + 8'd1;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CUMULATIVE;
                        rain_cum[0] <= {RAIN_SUM_WIDTH{1'b0}};
                        cum_index <= 5'd1;
                        min_wetness <= {DATA_WIDTH{1'b1}};
                    end
                end

                CUMULATIVE: begin
                    if (cum_index <= T) begin
                        rain_cum[cum_index] <= rain_cum[cum_index-5'd1] + rain[cum_index-5'd1];
                        cum_index <= cum_index + 5'd1;
                    end else begin
                        state <= PRE_SWEAT;
                    end
                end

                PRE_SWEAT: begin
                    // Precompute: 3600 * d^2 * c (fixed point)
                    numerator_reg <= (84'd3600 * d * d) * c;
                    dt_counter <= 5'd1;
                    state <= LOOP_DT;
                end

                LOOP_DT: begin
                    if (dt_counter <= T) begin
                        reg [DATA_WIDTH-1:0] rain_wetness;
                        reg [DATA_WIDTH-1:0] sweat_wetness;
                        reg [DATA_WIDTH-1:0] total_wetness;

                        rain_wetness = { {12{1'b0}}, rain_cum[dt_counter] } << 8; // Scale to Q16.8
                        // Compute sweat: (numerator_reg / (dt_counter * 65536))
                        sweat_wetness = (numerator_reg / (dt_counter * 84'd65536));
                        total_wetness = rain_wetness + sweat_wetness;

                        if (total_wetness < min_wetness) begin
                            min_wetness <= total_wetness;
                        end

                        dt_counter <= dt_counter + 5'd1;
                    end else begin
                        state <= DONE_ST;
                        result <= min_wetness;
                        done <= 1'b1;
                    end
                    
                    // Timeout safeguard
                    if (cycle_counter > 8'd200) begin
                        state <= DONE_ST;
                        result <= min_wetness;
                        done <= 1'b1;
                    end
                end

                DONE_ST: begin
                    state <= IDLE;
                    done <= 1'b0;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule