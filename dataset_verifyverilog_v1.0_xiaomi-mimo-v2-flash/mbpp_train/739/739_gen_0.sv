module triangular_index(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOOKUP = 3'd1;
    localparam [2:0] MULTIPLY = 3'd2;
    localparam [2:0] SQRT = 3'd3;
    localparam [2:0] ROUND = 3'd4;
    localparam [2:0] FINISH = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    // Registers
    reg [2:0] state, next_state;
    reg [3:0] n_reg;
    reg [15:0] power_10;
    reg [15:0] double_power;
    reg [31:0] sqrt_val;      // Q16.16 format for intermediate
    reg [31:0] sqrt_next;
    reg [31:0] sqrt_x;
    reg [4:0] sqrt_iter;       // Max 16 iterations
    reg [4:0] cycle_counter;
    reg [3:0] lookup_index;
    reg valid_n;

    // Local parameters for square root
    localparam [31:0] HALF = 32'h0000_8000;  // 0.5 in Q16.16
    localparam [4:0] MAX_SQRT_ITER = 5'd16;
    localparam [4:0] MAX_CYCLES = 5'd20;

    // 10^(n-1) lookup table (9 entries, 16-bit)
    // Index 0 is unused, n=1 => 10^0 = 1, n=9 => 10^8 = 100000000
    always @(*) begin
        case (lookup_index)
            4'd1: power_10 = 16'd1;          // 10^0
            4'd2: power_10 = 16'd10;         // 10^1
            4'd3: power_10 = 16'd100;        // 10^2
            4'd4: power_10 = 16'd1000;       // 10^3
            4'd5: power_10 = 16'd10000;      // 10^4
            4'd6: power_10 = 16'd5536;       // 10^5 truncated to 16 bits (100000)
            4'd7: power_10 = 16'd16960;      // 10^6 truncated (1000000)
            4'd8: power_10 = 16'd10000;      // 10^7 truncated (10000000)
            4'd9: power_10 = 16'd34464;      // 10^8 truncated (100000000)
            default: power_10 = 16'd0;
        endcase
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start && valid_n)
                    next_state = LOOKUP;
            end
            LOOKUP: next_state = MULTIPLY;
            MULTIPLY: next_state = SQRT;
            SQRT: begin
                if (sqrt_iter >= MAX_SQRT_ITER)
                    next_state = ROUND;
                else
                    next_state = SQRT;
            end
            ROUND: next_state = FINISH;
            FINISH: next_state = DONE_STATE;
            DONE_STATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            n_reg <= 4'd0;
            lookup_index <= 4'd0;
            double_power <= 16'd0;
            sqrt_val <= 32'd0;
            sqrt_next <= 32'd0;
            sqrt_x <= 32'd0;
            sqrt_iter <= 5'd0;
            cycle_counter <= 5'd0;
            valid_n <= 1'b0;
        end else begin
            state <= next_state;
            cycle_counter <= cycle_counter + 5'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 16'd0;
                    cycle_counter <= 5'd0;
                    
                    if (start) begin
                        n_reg <= n;
                        // Validate n is between 1 and 9
                        if (n >= 4'd1 && n <= 4'd9) begin
                            valid_n <= 1'b1;
                            lookup_index <= n;
                        end else begin
                            valid_n <= 1'b0;
                            result <= 16'd0;
                        end
                    end
                end
                
                LOOKUP: begin
                    // power_10 is already set by combinational logic
                    // Just verify valid n
                    if (!valid_n) begin
                        state <= DONE_STATE;
                    end
                end
                
                MULTIPLY: begin
                    // Multiply by 2 and convert to Q16.16
                    // double_power = power_10 * 2
                    // sqrt_x = {double_power, 16'd0} (shift left 16 bits)
                    double_power <= power_10 << 1;
                    // Initialize sqrt: sqrt_val = {double_power, 16'd0}
                    sqrt_val <= {power_10 << 1, 16'd0};
                    sqrt_next <= 32'd0;
                    sqrt_x <= {power_10 << 1, 16'd0};
                    sqrt_iter <= 5'd0;
                end
                
                SQRT: begin
                    // Newton-Raphson: x_next = 0.5 * (x + N/x)
                    // Need to handle division in Q16.16
                    // sqrt_x / sqrt_val in Q16.16
                    // We'll use: sqrt_next = (sqrt_val + (sqrt_x << 16) / sqrt_val) >> 1
                    
                    if (sqrt_iter == 5'd0) begin
                        // Initial guess: sqrt(x) ≈ x/2
                        sqrt_val <= sqrt_val >> 1;
                    end else begin
                        // Newton iteration
                        // Compute N/x where N = sqrt_x (already in Q16.16)
                        // Division: (N << 16) / sqrt_val (both are 32-bit)
                        // Simplified: use approximation
                        // sqrt_next = (sqrt_val + (sqrt_x / sqrt_val)) >> 1
                        // For Q16.16: sqrt_x / sqrt_val gives Q16.16 result
                        // We'll compute (sqrt_val + ((sqrt_x >> 8) / sqrt_val) << 8) >> 1
                        // To avoid overflow, scale down
                        
                        // Simple approximation: sqrt_next = (sqrt_val + (sqrt_x / sqrt_val)) >> 1
                        // (sqrt_x / sqrt_val) in Q16.16 format
                        // We compute: quotient = (sqrt_x << 16) / sqrt_val
                        // But that's 48-bit, so we use: (sqrt_x / (sqrt_val >> 8)) >> 8
                        
                        // Using: sqrt_next = (sqrt_val + ((sqrt_x << 8) / sqrt_val)) >> 1
                        // This keeps intermediate in 32-bit range
                        sqrt_val <= sqrt_val + (((sqrt_x << 8) / sqrt_val) >> 1);
                    end
                    
                    sqrt_iter <= sqrt_iter + 5'd1;
                end
                
                ROUND: begin
                    // Add 0.5 for rounding
                    // sqrt_val is in Q16.16 format
                    // result = (sqrt_val + 0.5) >> 16
                    result <= (sqrt_val + HALF) >> 16;
                end
                
                FINISH: begin
                    // Ensure result is valid
                    // Check if n was valid
                    if (!valid_n) begin
                        result <= 16'd0;
                    end
                    // Clamp to 16-bit range (though should already fit)
                    if (result > 16'd65535) begin
                        result <= 16'd65535;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 16'd0;
                    done <= 1'b0;
                end
            endcase
            
            // Timeout protection
            if (cycle_counter >= MAX_CYCLES && state != IDLE && state != DONE_STATE) begin
                state <= DONE_STATE;
                result <= 16'd0;
            end
        end
    end

endmodule