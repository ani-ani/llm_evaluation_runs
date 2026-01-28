module zero_ratio (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [3:0] len,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COUNT   = 3'd1;
    localparam [2:0] DIVIDE  = 3'd2;
    localparam [2:0] DONE    = 3'd3;
    localparam [2:0] ERROR   = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] idx;
    reg [3:0] zero_cnt;
    reg [3:0] nonzero_cnt;
    reg [31:0] numerator;    // zero_cnt * 2^16
    reg [31:0] denominator;
    reg [31:0] remainder;
    reg [31:0] quotient;
    reg [4:0] bit_counter;   // 0 to 16 for division

    // Next state logic
    always @(*) begin
        next_state = IDLE;
        case (state)
            IDLE: begin
                if (start)
                    next_state = COUNT;
                else
                    next_state = IDLE;
            end
            COUNT: begin
                if (idx == len)
                    next_state = DIVIDE;
                else
                    next_state = COUNT;
            end
            DIVIDE: begin
                // Division done when bit_counter reaches 17 (0..16 processed)
                if (bit_counter == 5'd17)
                    next_state = DONE;
                else
                    next_state = DIVIDE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            idx <= 4'd0;
            zero_cnt <= 4'd0;
            nonzero_cnt <= 4'd0;
            numerator <= 32'd0;
            denominator <= 32'd0;
            remainder <= 32'd0;
            quotient <= 32'd0;
            bit_counter <= 5'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    result <= 32'd0;
                    done <= 1'b0;
                    idx <= 4'd0;
                    zero_cnt <= 4'd0;
                    nonzero_cnt <= 4'd0;
                    numerator <= 32'd0;
                    denominator <= 32'd0;
                    remainder <= 32'd0;
                    quotient <= 32'd0;
                    bit_counter <= 5'd0;
                end

                COUNT: begin
                    // Count zeros and non-zeros
                    if (arr[idx] == 8'd0) begin
                        zero_cnt <= zero_cnt + 4'd1;
                    end else begin
                        nonzero_cnt <= nonzero_cnt + 4'd1;
                    end
                    idx <= idx + 4'd1;
                end

                DIVIDE: begin
                    // On first cycle of DIVIDE, set up division
                    if (bit_counter == 5'd0) begin
                        // Prepare numerator = zero_cnt * 2^16
                        numerator <= {zero_cnt, 16'd0};
                        denominator <= {28'd0, nonzero_cnt};
                        remainder <= 32'd0;
                        quotient <= 32'd0;
                        bit_counter <= bit_counter + 5'd1;
                    end else begin
                        // Bitwise division algorithm (shift-subtract)
                        // Shift numerator left into remainder
                        remainder <= {remainder[30:0], numerator[31]};
                        numerator <= {numerator[30:0], 1'b0};
                        quotient <= {quotient[30:0], 1'b0};

                        // Compare and subtract (delayed by 1 cycle to align with quotient LSB)
                        if (bit_counter >= 5'd2) begin
                            if (remainder >= denominator) begin
                                remainder <= remainder - denominator;
                                quotient[0] <= 1'b1;
                            end
                        end
                        bit_counter <= bit_counter + 5'd1;
                    end
                end

                DONE: begin
                    // If denominator was 0, output 0 (handled by initial state)
                    if (nonzero_cnt == 4'd0) begin
                        result <= 32'd0;
                    end else begin
                        result <= quotient;
                    end
                    done <= 1'b1;
                    idx <= 4'd0;
                    zero_cnt <= 4'd0;
                    nonzero_cnt <= 4'd0;
                    numerator <= 32'd0;
                    denominator <= 32'd0;
                    remainder <= 32'd0;
                    quotient <= 32'd0;
                    bit_counter <= 5'd0;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule