module max_bags_finder(
    input clk,
    input rst_n,
    input start,
    input [31:0] m_in,
    input [31:0] k_in,
    output reg [31:0] result,
    output reg done
);

    localparam [31:0] MOD = 32'd998244353;
    localparam [31:0] MAX_CYCLES = 32'd1000;
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_BASE = 3'd1;
    localparam [2:0] EXPONENTIATION = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state;
    reg [31:0] m_reg;
    reg [31:0] k_reg;
    reg [31:0] base;
    reg [31:0] result_reg;
    reg [31:0] exponent;
    reg [31:0] cycle_counter;
    reg [5:0] bit_counter;  // 0 to 31 for 32-bit exponent
    
    // For multiplication (64-bit intermediate)
    reg [63:0] temp_mult;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            m_reg <= 32'd0;
            k_reg <= 32'd0;
            base <= 32'd0;
            result_reg <= 32'd0;
            exponent <= 32'd0;
            cycle_counter <= 32'd0;
            bit_counter <= 6'd0;
            temp_mult <= 64'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 32'd0;
                    bit_counter <= 6'd0;
                    if (start) begin
                        m_reg <= m_in;
                        k_reg <= k_in;
                        state <= COMPUTE_BASE;
                    end
                end
                
                COMPUTE_BASE: begin
                    // Compute base = (2*m + 1) % MOD
                    // 2*m can be up to 2*10^6, fits in 32-bit
                    temp_mult <= {32'd0, m_reg} * 32'd2;
                    base <= (temp_mult[31:0] + 32'd1) % MOD;
                    result_reg <= 32'd1;  // Initialize result for exponentiation
                    exponent <= k_reg;
                    state <= EXPONENTIATION;
                end
                
                EXPONENTIATION: begin
                    // Binary exponentiation (square-and-multiply)
                    // Process bit by bit from LSB to MSB
                    
                    if (bit_counter < 32) begin
                        // Square the base
                        temp_mult <= {32'd0, base} * base;
                        
                        // If current bit of exponent is 1, multiply result by base
                        if (exponent[bit_counter]) begin
                            // result = (result * base) % MOD
                            temp_mult <= {32'd0, result_reg} * base;
                            // After multiplication, need to apply modulo
                        end
                        
                        bit_counter <= bit_counter + 6'd1;
                        cycle_counter <= cycle_counter + 32'd1;
                        
                        // Check if all bits processed or timeout
                        if (bit_counter >= 5'd31) begin
                            state <= FINISH;
                        end
                    end
                end
                
                FINISH: begin
                    result <= result_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Additional cycle for modulo operation after multiplication
            // We need to handle the multiplication results from EXPONENTIATION state
            // This needs to be outside the case statement to catch multi-cycle operations
            if (state == EXPONENTIATION && bit_counter > 6'd0) begin
                // Apply modulo to the temp_mult result
                if (temp_mult[31:0] == exponent[bit_counter-6'd1]) begin
                    // This was a result multiplication
                    result_reg <= temp_mult[63:32] % MOD;
                end else begin
                    // This was a base squaring
                    base <= temp_mult[63:32] % MOD;
                end
            end
        end
    end

endmodule