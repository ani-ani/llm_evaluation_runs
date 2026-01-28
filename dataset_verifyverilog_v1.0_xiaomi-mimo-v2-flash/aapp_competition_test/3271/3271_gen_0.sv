module PermutationInversions (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [7:0] C,
    output reg [31:0] result,
    output reg done,
    output reg busy
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [3:0] MAX_N = 4'd10;
    localparam [7:0] MAX_C = 8'd256;
    localparam [7:0] MAX_CYCLES = 8'd100; // Capped for safety
    
    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] INIT       = 3'd1;
    localparam [2:0] COMPUTE_N  = 3'd2;
    localparam [2:0] COMPUTE_C  = 3'd3;
    localparam [2:0] SUM_LOOP   = 3'd4;
    localparam [2:0] UPDATE     = 3'd5;
    localparam [2:0] DONE       = 3'd6;
    
    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] n_idx;           // Current n (1 to N)
    reg [7:0] c_idx;           // Current c (0 to C)
    reg [7:0] k_idx;           // Loop variable for summation
    reg [31:0] sum_temp;       // Accumulator for dp[n-1][c-k]
    reg [7:0] target_N;        // Clamped N
    reg [7:0] target_C;        // Clamped C
    reg [7:0] max_k;           // min(c_idx, n_idx-1)
    
    // Flattened DP array: dp[n][c] -> index = n*(MAX_C+1) + c
    // n: 0..10 (11 values), c: 0..256 (257 values)
    // Total: 11 * 257 = 2827 entries
    localparam [15:0] DP_SIZE = 16'd2827;
    reg [31:0] dp_reg [0:2826];
    integer i;
    
    // Helper wires for index calculation
    wire [15:0] idx_n_minus_1;
    wire [15:0] idx_n;
    wire [15:0] idx_prev_c;
    wire [15:0] idx_curr_c;
    
    assign idx_n_minus_1 = (n_idx - 8'd1) * 16'd257 + c_idx;
    assign idx_n = n_idx * 16'd257 + c_idx;
    assign idx_prev_c = (n_idx - 8'd1) * 16'd257 + (c_idx - k_idx);
    assign idx_curr_c = n_idx * 16'd257 + c_idx;
    
    // Overflow protection for addition
    wire [31:0] sum_add;
    wire [31:0] sum_mod;
    assign sum_add = sum_temp + dp_reg[idx_prev_c];
    assign sum_mod = (sum_add >= MOD) ? (sum_add - MOD) : sum_add;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            busy <= 1'b0;
            n_idx <= 4'd0;
            c_idx <= 8'd0;
            k_idx <= 8'd0;
            sum_temp <= 32'd0;
            target_N <= 8'd0;
            target_C <= 8'd0;
            // Initialize all DP entries to 0
            for (i = 0; i < 2827; i = i + 1) begin
                dp_reg[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    if (start) begin
                        busy <= 1'b1;
                        target_N <= (N > MAX_N) ? MAX_N : N;
                        target_C <= (C > MAX_C) ? MAX_C : C;
                    end
                end
                
                INIT: begin
                    // Reset all DP entries to 0
                    for (i = 0; i < 2827; i = i + 1) begin
                        dp_reg[i] <= 32'd0;
                    end
                    // Set dp[0][0] = 1
                    dp_reg[16'd0] <= 32'd1;
                    n_idx <= 4'd1;
                    c_idx <= 8'd0;
                end
                
                COMPUTE_N: begin
                    c_idx <= 8'd0;
                end
                
                COMPUTE_C: begin
                    sum_temp <= 32'd0;
                    k_idx <= 8'd0;
                    max_k <= (c_idx < (n_idx - 8'd1)) ? c_idx : (n_idx - 8'd1);
                end
                
                SUM_LOOP: begin
                    if (k_idx <= max_k) begin
                        // Check bounds before accessing dp_reg
                        if (c_idx >= k_idx) begin
                            sum_temp <= sum_mod;
                        end
                        k_idx <= k_idx + 8'd1;
                    end
                end
                
                UPDATE: begin
                    // Store computed value
                    if (c_idx <= target_C) begin
                        dp_reg[idx_curr_c] <= sum_temp;
                    end
                end
                
                DONE: begin
                    // Final result is dp[N][C]
                    result <= dp_reg[target_N * 16'd257 + target_C];
                    done <= 1'b1;
                    busy <= 1'b0;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end
            
            INIT: begin
                next_state = COMPUTE_N;
            end
            
            COMPUTE_N: begin
                if (n_idx > target_N) begin
                    next_state = DONE;
                end else begin
                    next_state = COMPUTE_C;
                end
            end
            
            COMPUTE_C: begin
                if (c_idx > target_C) begin
                    // Move to next n
                    next_state = COMPUTE_N;
                end else begin
                    next_state = SUM_LOOP;
                end
            end
            
            SUM_LOOP: begin
                if (k_idx > max_k) begin
                    next_state = UPDATE;
                end else begin
                    next_state = SUM_LOOP;
                end
            end
            
            UPDATE: begin
                next_state = COMPUTE_C;
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
endmodule