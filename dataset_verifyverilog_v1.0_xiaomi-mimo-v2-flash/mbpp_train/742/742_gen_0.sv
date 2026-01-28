module tetrahedron_area(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] side,  // Q16.16
    output reg [31:0] result, // Q16.16
    output reg done
);

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] SQUARING = 3'd1;
    localparam [2:0] MULTIPLY = 3'd2;
    localparam [2:0] SQRT     = 3'd3;
    localparam [2:0] DONE     = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Constants
    localparam [31:0] SQRT3_Q16_16 = 32'h0001B504;  // 1.7320508075688772 in Q16.16
    localparam [31:0] MAX_RESULT    = 32'hFFFFFFFF;  // Saturate at max
    
    // Pipeline registers
    reg [31:0] side_reg;
    reg [63:0] square_prod;     // 64-bit product for square
    reg [63:0] multiply_prod;   // 64-bit product for multiply by sqrt3
    reg [47:0] sqrt_input;      // 48-bit input for sqrt
    reg [31:0] sqrt_result;     // Q8.24 result from sqrt
    reg [31:0] result_reg;      // Final Q16.16 result
    
    // Sqrt iteration variables
    reg [5:0] sqrt_iter;        // Iteration counter (max 48)
    reg [47:0] sqrt_rem;        // Remainder
    reg [31:0] sqrt_res;        // Result being built
    reg [31:0] sqrt_bit;        // Current bit to test
    
    // Counter for state timing
    reg [5:0] cycle_counter;
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = SQUARING;
                else
                    next_state = IDLE;
            end
            SQUARING: begin
                // Single cycle multiply (combinational)
                next_state = MULTIPLY;
            end
            MULTIPLY: begin
                // Single cycle multiply (combinational)
                next_state = SQRT;
            end
            SQRT: begin
                // Iterate sqrt (max 48 cycles)
                if (sqrt_iter >= 6'd48)
                    next_state = DONE;
                else
                    next_state = SQRT;
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
            done <= 1'b0;
            result <= 32'd0;
            side_reg <= 32'd0;
            square_prod <= 64'd0;
            multiply_prod <= 64'd0;
            sqrt_input <= 48'd0;
            sqrt_result <= 32'd0;
            result_reg <= 32'd0;
            sqrt_iter <= 6'd0;
            sqrt_rem <= 48'd0;
            sqrt_res <= 32'd0;
            sqrt_bit <= 32'd0;
            cycle_counter <= 6'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        side_reg <= side;
                        cycle_counter <= 6'd0;
                    end
                end
                
                SQUARING: begin
                    // side × side (Q16.16 × Q16.16 = Q32.32, keep Q16.16 from [47:16])
                    square_prod <= side_reg * side_reg;
                    cycle_counter <= cycle_counter + 6'd1;
                end
                
                MULTIPLY: begin
                    // square_result × √3 (Q16.16 × Q16.16 = Q32.32)
                    // square_result = square_prod[47:16]
                    multiply_prod <= square_prod[47:16] * SQRT3_Q16_16;
                    cycle_counter <= cycle_counter + 6'd1;
                end
                
                SQRT: begin
                    if (sqrt_iter == 6'd0) begin
                        // Initialize sqrt: take middle 48 bits of multiply_prod
                        // multiply_prod is Q32.32, we need Q16.48 for sqrt
                        // Actually: multiply_prod[47:16] is Q16.16, shift left 32 bits for Q16.48
                        sqrt_input <= {multiply_prod[47:16], 16'd0};
                        sqrt_rem <= 48'd0;
                        sqrt_res <= 32'd0;
                        sqrt_bit <= 32'h80000000;  // Start with bit 31
                        sqrt_iter <= 6'd1;
                    end else if (sqrt_iter <= 6'd48) begin
                        // Binary search sqrt algorithm
                        // sqrt_res is Q8.24, we need Q16.16 at end
                        if (sqrt_rem >= ({sqrt_rem[45:0], 2'd0} | (({sqrt_bit, 24'd0} >> 24)))) begin
                            sqrt_rem <= sqrt_rem - ({sqrt_rem[45:0], 2'd0} | (({sqrt_bit, 24'd0} >> 24)));
                            sqrt_res <= sqrt_res | sqrt_bit;
                        end
                        sqrt_bit <= sqrt_bit >> 1;
                        sqrt_iter <= sqrt_iter + 6'd1;
                    end
                    cycle_counter <= cycle_counter + 6'd1;
                end
                
                DONE: begin
                    // Convert Q8.24 to Q16.16 by shifting right 8 bits
                    // sqrt_res[31:0] is Q8.24, shift to Q16.16
                    result_reg <= sqrt_res >> 8;
                    result <= (side_reg == 32'd0) ? 32'd0 : (sqrt_res >> 8);
                    done <= 1'b1;
                    sqrt_iter <= 6'd0;  // Reset for next operation
                    cycle_counter <= 6'd0;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 32'd0;
                end
            endcase
        end
    end

endmodule