module mean_absolute_deviation(
    input clk,
    input rst_n,
    input start,
    input [4:0] count,
    input [31:0] numbers [0:7],
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CALC_MEAN = 3'd1;
    localparam [2:0] CALC_DIFF = 3'd2;
    localparam [2:0] CALC_AVG  = 3'd3;
    localparam [2:0] FINISH    = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Internal registers
    reg [31:0] mean;
    reg [39:0] sum;  // 40-bit accumulator for sums
    reg [39:0] abs_sum;
    reg [7:0] index;
    reg [31:0] current_num;
    reg [31:0] abs_diff;

    // Division state machine
    localparam [3:0] DIV_IDLE = 4'd0;
    localparam [3:0] DIV_SUB  = 4'd1;
    localparam [3:0] DIV_DONE = 4'd2;
    reg [3:0] div_state;
    reg [31:0] dividend;
    reg [15:0] divisor;
    reg [31:0] quotient;
    reg [7:0] div_cycle;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            mean <= 32'd0;
            sum <= 40'd0;
            abs_sum <= 40'd0;
            index <= 8'd0;
            current_num <= 32'd0;
            abs_diff <= 32'd0;
            div_state <= DIV_IDLE;
            dividend <= 32'd0;
            divisor <= 16'd0;
            quotient <= 32'd0;
            div_cycle <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= CALC_MEAN;
                        sum <= 40'd0;
                        index <= 8'd0;
                    end
                end

                CALC_MEAN: begin
                    if (index < count) begin
                        current_num <= numbers[index];
                        sum <= sum + {1'b0, current_num};
                        index <= index + 8'd1;
                    end else begin
                        // Start division for mean
                        dividend <= sum[39:8];  // Upper 32 bits of sum
                        divisor <= count;
                        div_state <= DIV_SUB;
                        div_cycle <= 8'd0;
                        quotient <= 32'd0;
                        next_state <= CALC_MEAN;  // Stay in CALC_MEAN during division
                    end
                end

                CALC_DIFF: begin
                    if (index < count) begin
                        current_num <= numbers[index];
                        // Compute absolute difference
                        if (current_num[31]) begin
                            abs_diff <= ~current_num + 32'd1;
                        end else begin
                            abs_diff <= current_num;
                        end
                        // Subtract mean
                        if (mean[31]) begin
                            abs_diff <= abs_diff + ~mean + 32'd1;
                        end else begin
                            abs_diff <= abs_diff - mean;
                        end
                        // Take absolute value of difference
                        if (abs_diff[31]) begin
                            abs_diff <= ~abs_diff + 32'd1;
                        end
                        abs_sum <= abs_sum + {1'b0, abs_diff};
                        index <= index + 8'd1;
                    end else begin
                        // Start division for MAD
                        dividend <= abs_sum[39:8];  // Upper 32 bits of abs_sum
                        divisor <= count;
                        div_state <= DIV_SUB;
                        div_cycle <= 8'd0;
                        quotient <= 32'd0;
                        next_state <= CALC_DIFF;  // Stay in CALC_DIFF during division
                    end
                end

                CALC_AVG: begin
                    // Division result is ready
                    result <= quotient;
                    next_state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase

            // Division state machine
            case (div_state)
                DIV_IDLE: begin
                    // Do nothing
                end

                DIV_SUB: begin
                    if (div_cycle < 17) begin
                        // Shift dividend and quotient left
                        dividend <= dividend << 1;
                        quotient <= quotient << 1;
                        // Subtract divisor if possible
                        if (dividend[31:16] >= divisor) begin
                            dividend[31:16] <= dividend[31:16] - divisor;
                            quotient[0] <= 1'b1;
                        end
                        div_cycle <= div_cycle + 8'd1;
                    end else begin
                        div_state <= DIV_DONE;
                        if (state == CALC_MEAN) begin
                            mean <= quotient;
                            index <= 8'd0;
                            abs_sum <= 40'd0;
                            next_state <= CALC_DIFF;
                        end else if (state == CALC_DIFF) begin
                            next_state <= CALC_AVG;
                        end
                    end
                end

                DIV_DONE: begin
                    // Do nothing
                end

                default: div_state <= DIV_IDLE;
            endcase
        end
    end

endmodule