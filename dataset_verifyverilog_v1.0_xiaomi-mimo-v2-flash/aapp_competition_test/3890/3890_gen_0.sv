module compute_plaque_ways (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [9:0] n_in,
    input wire [9:0] k_in,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] EXP1 = 2'd1;
    localparam [1:0] EXP2 = 2'd2;
    localparam [1:0] MULT = 2'd3;
    
    // State and next state
    reg [1:0] state;
    reg [1:0] next_state;
    
    // Input registers
    reg [9:0] n_reg;
    reg [9:0] k_reg;
    
    // Modular exponentiation variables
    reg [31:0] exp_base;
    reg [31:0] exp_exp;
    reg [31:0] exp_result;
    reg [31:0] exp_temp;
    reg [9:0] exp_counter;
    reg exp_start;
    reg exp_done;
    
    // Multiplication variables
    reg [31:0] mult_a;
    reg [31:0] mult_b;
    reg [31:0] mult_result;
    reg mult_start;
    reg mult_done;
    
    // Intermediate results
    reg [31:0] pow1_result;
    reg [31:0] pow2_result;
    
    // Cycle counter for timeout protection
    reg [9:0] cycle_counter;
    localparam [9:0] MAX_CYCLES = 10'd1000;
    
    // Multiplication module (single cycle)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_result <= 32'd0;
            mult_done <= 1'b0;
        end else if (mult_start) begin
            mult_result <= (mult_a * mult_b) % MOD;
            mult_done <= 1'b1;
        end else begin
            mult_done <= 1'b0;
        end
    end
    
    // Modular exponentiation module
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            exp_result <= 32'd0;
            exp_temp <= 32'd0;
            exp_counter <= 10'd0;
            exp_done <= 1'b0;
        end else if (exp_start) begin
            // Initialize
            if (exp_counter == 10'd0) begin
                exp_result <= 32'd1;
                exp_temp <= exp_base % MOD;
                exp_counter <= 10'd1;
                exp_done <= 1'b0;
            end else if (exp_counter <= exp_exp) begin
                // Square and multiply
                if (exp_counter[0] == 1'b1) begin
                    // Odd: multiply result by temp
                    exp_result <= (exp_result * exp_temp) % MOD;
                end
                // Square temp
                exp_temp <= (exp_temp * exp_temp) % MOD;
                exp_counter <= exp_counter + 10'd1;
                exp_done <= 1'b0;
            end else begin
                // Done
                exp_done <= 1'b1;
                exp_counter <= 10'd0;
            end
        end else begin
            exp_done <= 1'b0;
        end
    end
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_counter <= 10'd0;
            n_reg <= 10'd0;
            k_reg <= 10'd0;
            pow1_result <= 32'd0;
            pow2_result <= 32'd0;
            exp_start <= 1'b0;
            mult_start <= 1'b0;
        end else begin
            cycle_counter <= cycle_counter + 10'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 10'd0;
                    exp_start <= 1'b0;
                    mult_start <= 1'b0;
                    
                    if (start) begin
                        n_reg <= n_in;
                        k_reg <= k_in;
                        
                        // Check invalid inputs
                        if (k_in < 10'd1 || k_in > n_in) begin
                            result <= 32'd0;
                            done <= 1'b1;
                            state <= IDLE;
                        end else if (k_in == n_in) begin
                            // Only k^(k-1) needed
                            exp_base <= k_in;
                            exp_exp <= k_in - 10'd1;
                            exp_start <= 1'b1;
                            state <= EXP1;
                        end else begin
                            // Both terms needed
                            exp_base <= k_in;
                            exp_exp <= k_in - 10'd1;
                            exp_start <= 1'b1;
                            state <= EXP1;
                        end
                    end
                end
                
                EXP1: begin
                    exp_start <= 1'b0;
                    if (exp_done) begin
                        pow1_result <= exp_result;
                        
                        if (n_reg == k_reg) begin
                            // Only one term
                            result <= exp_result;
                            done <= 1'b1;
                            state <= IDLE;
                        end else begin
                            // Compute second term: (n-k)^(n-k)
                            exp_base <= n_reg - k_reg;
                            exp_exp <= n_reg - k_reg;
                            exp_start <= 1'b1;
                            state <= EXP2;
                        end
                    end
                    // Timeout protection
                    if (cycle_counter >= MAX_CYCLES) begin
                        result <= 32'd0;
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end
                
                EXP2: begin
                    exp_start <= 1'b0;
                    if (exp_done) begin
                        pow2_result <= exp_result;
                        mult_a <= pow1_result;
                        mult_b <= exp_result;
                        mult_start <= 1'b1;
                        state <= MULT;
                    end
                    // Timeout protection
                    if (cycle_counter >= MAX_CYCLES) begin
                        result <= 32'd0;
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end
                
                MULT: begin
                    mult_start <= 1'b0;
                    if (mult_done) begin
                        result <= mult_result;
                        done <= 1'b1;
                        state <= IDLE;
                    end
                    // Timeout protection
                    if (cycle_counter >= MAX_CYCLES) begin
                        result <= 32'd0;
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule