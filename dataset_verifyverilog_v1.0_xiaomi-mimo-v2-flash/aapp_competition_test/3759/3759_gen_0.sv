module ChubbyYang (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [25:0] n_in,
    output reg [31:0] result,
    output reg done
);
    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] CHECK_N  = 3'd1;
    localparam [2:0] MULT     = 3'd2;
    localparam [2:0] ROUND    = 3'd3;
    localparam [2:0] FINISH   = 3'd4;
    
    // Fixed-point constant: sqrt(2) in Q32.32 format
    // sqrt(2) ≈ 1.4142135623730951 = 0x1.6A09E667F3BCD
    localparam [63:0] SQRT2_FIXED = 64'h16A09E667F3BCD;
    
    // State registers
    reg [2:0] state, next_state;
    reg [2:0] cycle_counter;
    localparam [2:0] MAX_CYCLES = 3'd5;
    
    // Computation registers
    reg [25:0] n_reg;
    reg [63:0] mult_temp;      // 64-bit intermediate for multiplication
    reg [31:0] result_temp;
    reg [2:0] case_check;      // To track which case we're in
    
    // Control signals
    reg compute_start;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            n_reg <= 26'd0;
            mult_temp <= 64'd0;
            result_temp <= 32'd0;
            cycle_counter <= 3'd0;
            compute_start <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 3'd0;
                    if (start) begin
                        n_reg <= n_in;
                        compute_start <= 1'b1;
                        state <= CHECK_N;
                    end
                end
                
                CHECK_N: begin
                    compute_start <= 1'b0;
                    if (n_reg == 26'd0) begin
                        result_temp <= 32'd1;
                        state <= FINISH;
                    end else begin
                        state <= MULT;
                    end
                end
                
                MULT: begin
                    // Compute n * sqrt(2) in Q32.32
                    // Using 26-bit n and 64-bit sqrt2
                    // Result needs 90 bits, but we'll use 64-bit temp
                    mult_temp <= n_reg * SQRT2_FIXED[63:32];
                    // Continue to next cycle
                    cycle_counter <= cycle_counter + 3'd1;
                    state <= ROUND;
                end
                
                ROUND: begin
                    // Extract upper 32 bits (integer part) from Q32.32 result
                    // mult_temp is n * (sqrt2 >> 32) in Q26.0 format
                    // Actually, we need: (n * sqrt2_fixed) >> 32
                    // where sqrt2_fixed = 1.414... in Q32.32
                    
                    // Correct computation: n (26-bit) * sqrt2 (64-bit Q32.32)
                    // = (26 + 32 + 32) = 90 bits total
                    // We want bits [89:58] (integer part)
                    
                    // For this implementation, we'll do:
                    // 1. Multiply n by sqrt2's integer part (0x16A09E66)
                    // 2. Add the fractional contribution
                    
                    // Simpler approach: use pre-computed multiplier
                    // result = floor(4*n*sqrt(2)) = 4 * (n * sqrt2 >> 32)
                    
                    // Multiply n (26-bit) by sqrt2_int (32-bit)
                    mult_temp <= n_reg * SQRT2_FIXED[63:32];  // 26x32 = 58 bits
                    
                    // Add fractional contribution (scaled)
                    // sqrt2_frac = 0x7F3BCD (28 bits)
                    // contribution = (n * sqrt2_frac) >> 28
                    
                    result_temp <= mult_temp[57:26] + ((n_reg * SQRT2_FIXED[31:0]) >> 28);
                    
                    cycle_counter <= cycle_counter + 3'd1;
                    state <= FINISH;
                end
                
                FINISH: begin
                    // Final result is 4 * result_temp (shift left 2)
                    result <= {result_temp[29:0], 2'd0};
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule