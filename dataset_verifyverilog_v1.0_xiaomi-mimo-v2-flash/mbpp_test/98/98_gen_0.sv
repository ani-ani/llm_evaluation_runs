module list_product_divide (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] data_in [0:15],
    input wire [3:0] length,
    output reg signed [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] MULTIPLY = 2'd1;
    localparam [1:0] DIVIDE = 2'd2;
    localparam [1:0] OUTPUT = 2'd3;

    // Registers
    reg [1:0] state, next_state;
    reg [3:0] index;
    reg [3:0] cycle_count;
    reg signed [31:0] accumulator;
    reg signed [31:0] product_temp;
    reg signed [31:0] div_temp;
    reg signed [31:0] result_reg;
    reg done_reg;
    
    // Constants
    localparam signed [31:0] ONE_POINT_ZERO = 32'd65536; // 1.0 in Q16.16
    localparam signed [31:0] MAX_POS = 32'h7FFFFFFF;
    localparam signed [31:0] MIN_NEG = 32'h80000000;
    localparam [3:0] MAX_CYCLES = 4'd15; // Max 15 elements

    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            cycle_count <= 4'd0;
            accumulator <= 32'd0;
            product_temp <= 32'd0;
            div_temp <= 32'd0;
            result_reg <= 32'd0;
            done_reg <= 1'b0;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done_reg <= 1'b0;
                    done <= 1'b0;
                    result <= 32'd0;
                    index <= 4'd0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= MULTIPLY;
                        accumulator <= ONE_POINT_ZERO; // Start with 1.0
                    end
                end

                MULTIPLY: begin
                    // Multiply accumulator by input[index] (treated as Q16.0)
                    // Input is Q16.0, accumulator is Q16.16
                    // Result is Q32.16, we keep Q32.0 for intermediate
                    product_temp <= accumulator * data_in[index];
                    
                    // Check for overflow/clamp after multiplication
                    // Since we're scaling down, we'll handle in next cycle
                    
                    index <= index + 4'd1;
                    cycle_count <= cycle_count + 4'd1;
                    
                    if (cycle_count >= length - 4'd1) begin
                        state <= DIVIDE;
                        // Scale product from Q32.16 to Q32.0 for intermediate storage
                        // Shift right by 16 bits, but keep it as Q32.0
                        accumulator <= product_temp >>> 16;
                    end
                end

                DIVIDE: begin
                    // Perform division: accumulator / length
                    // accumulator is Q32.0, result needs to be Q16.16
                    // So we shift left by 16 before division
                    div_temp <= (accumulator * 65536) / length;
                    state <= OUTPUT;
                end

                OUTPUT: begin
                    // Clamp result to 32-bit signed range
                    if (div_temp > MAX_POS) begin
                        result_reg <= MAX_POS;
                    end else if (div_temp < MIN_NEG) begin
                        result_reg <= MIN_NEG;
                    end else begin
                        result_reg <= div_temp;
                    end
                    done_reg <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Output registration
            result <= result_reg;
            done <= done_reg;
        end
    end

endmodule