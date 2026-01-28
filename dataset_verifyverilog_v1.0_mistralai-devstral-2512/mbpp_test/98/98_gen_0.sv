module FixedPointProductDivide(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] data_in [0:15],
    input wire [3:0] length,
    output reg signed [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] MULTIPLY = 3'd1;
    localparam [2:0] DIVIDE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;

    reg [2:0] state, next_state;
    reg [3:0] counter;
    reg signed [31:0] accumulator;
    reg signed [31:0] product;
    reg signed [31:0] temp_result;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd18;

    // Pre-computed reciprocals for lengths 1-15 (Q16.16 format)
    localparam signed [31:0] RECIPROCAL_1 = 32'sd1 << 16;  // 1.0
    localparam signed [31:0] RECIPROCAL_2 = 32'sd32768;    // 0.5
    localparam signed [31:0] RECIPROCAL_3 = 32'sd21845;    // 0.333...
    localparam signed [31:0] RECIPROCAL_4 = 32'sd16384;    // 0.25
    localparam signed [31:0] RECIPROCAL_5 = 32'sd13107;    // 0.2
    localparam signed [31:0] RECIPROCAL_6 = 32'sd10922;    // 0.1666...
    localparam signed [31:0] RECIPROCAL_7 = 32'sd9362;     // 0.1428...
    localparam signed [31:0] RECIPROCAL_8 = 32'sd8192;     // 0.125
    localparam signed [31:0] RECIPROCAL_9 = 32'sd7281;     // 0.111...
    localparam signed [31:0] RECIPROCAL_10 = 32'sd6553;    // 0.1
    localparam signed [31:0] RECIPROCAL_11 = 32'sd5957;    // 0.0909...
    localparam signed [31:0] RECIPROCAL_12 = 32'sd5461;    // 0.0833...
    localparam signed [31:0] RECIPROCAL_13 = 32'sd5030;    // 0.0769...
    localparam signed [31:0] RECIPROCAL_14 = 32'sd4681;    // 0.0714...
    localparam signed [31:0] RECIPROCAL_15 = 32'sd4369;    // 0.0666...

    // Reciprocal lookup
    wire signed [31:0] reciprocal;
    always @(*) begin
        case (length)
            4'd1:  reciprocal = RECIPROCAL_1;
            4'd2:  reciprocal = RECIPROCAL_2;
            4'd3:  reciprocal = RECIPROCAL_3;
            4'd4:  reciprocal = RECIPROCAL_4;
            4'd5:  reciprocal = RECIPROCAL_5;
            4'd6:  reciprocal = RECIPROCAL_6;
            4'd7:  reciprocal = RECIPROCAL_7;
            4'd8:  reciprocal = RECIPROCAL_8;
            4'd9:  reciprocal = RECIPROCAL_9;
            4'd10: reciprocal = RECIPROCAL_10;
            4'd11: reciprocal = RECIPROCAL_11;
            4'd12: reciprocal = RECIPROCAL_12;
            4'd13: reciprocal = RECIPROCAL_13;
            4'd14: reciprocal = RECIPROCAL_14;
            4'd15: reciprocal = RECIPROCAL_15;
            default: reciprocal = RECIPROCAL_1;
        endcase
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            counter <= 4'd0;
            accumulator <= 32'sd0;
            product <= 32'sd0;
            temp_result <= 32'sd0;
            result <= 32'sd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= MULTIPLY;
                        counter <= 4'd0;
                        accumulator <= 32'sd65536;  // 1.0 in Q16.16
                    end else begin
                        next_state <= IDLE;
                    end
                end

                MULTIPLY: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (counter < length) begin
                        // Multiply accumulator by data_in[counter] (Q16.0)
                        // Convert data_in to Q16.16 by shifting left 16 bits
                        product = accumulator * ({data_in[counter], 16'd0});
                        // Scale back to Q16.16 by shifting right 16 bits
                        accumulator = product[47:16];
                        // Overflow handling: clamp to 32-bit signed range
                        if (accumulator > 32'sd2147483647) begin
                            accumulator = 32'sd2147483647;
                        end else if (accumulator < 32'sd-2147483648) begin
                            accumulator = 32'sd-2147483648;
                        end
                        counter <= counter + 4'd1;
                        next_state <= MULTIPLY;
                    end else begin
                        next_state <= DIVIDE;
                    end
                end

                DIVIDE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Multiply by reciprocal (Q16.16 * Q16.16 = Q32.32)
                    // Then shift right 16 bits to get Q16.16
                    temp_result = (accumulator * reciprocal) >> 16;
                    // Overflow handling
                    if (temp_result > 32'sd2147483647) begin
                        temp_result = 32'sd2147483647;
                    end else if (temp_result < 32'sd-2147483648) begin
                        temp_result = 32'sd-2147483648;
                    end
                    next_state <= OUTPUT;
                end

                OUTPUT: begin
                    cycle_count <= cycle_count + 8'd1;
                    result <= temp_result;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule