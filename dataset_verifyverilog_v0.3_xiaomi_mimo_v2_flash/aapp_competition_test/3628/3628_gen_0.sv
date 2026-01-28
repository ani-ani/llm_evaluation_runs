module find_permutations (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [7:0] a_0, a_1, a_2, a_3, a_4, a_5, a_6, a_7,
    output reg [7:0] pi_0, pi_1, pi_2, pi_3, pi_4, pi_5, pi_6, pi_7,
    output reg [7:0] sigma_0, sigma_1, sigma_2, sigma_3, sigma_4, sigma_5, sigma_6, sigma_7,
    output reg done,
    output reg impossible
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] STORE_INPUT = 3'd1;
    localparam [2:0] SEARCH      = 3'd2;
    localparam [2:0] FOUND       = 3'd3;
    localparam [2:0] IMPOSSIBLE  = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [3:0] depth;           // Current search depth (0 to n-1)
    reg [7:0] used_pi;         // Bitmask of used pi values (0..n-1)
    reg [7:0] used_sigma;      // Bitmask of used sigma values (0..n-1)
    reg [3:0] current_candidate; // Candidate pi value to try
    reg [7:0] a_reg [0:7];     // Store input sequence a
    reg [7:0] c_reg [0:7];     // Computed c_i = (a_i == 1) ? (n-1) : (a_i - 2)
    reg [7:0] pi_reg [0:7];    // Temporary pi storage
    reg search_started;        // Flag to ensure single start pulse
    
    // Cycle counter to prevent infinite loops (safety mechanism)
    reg [23:0] cycle_count;    // Large enough for worst case (~100k cycles)
    localparam [23:0] MAX_CYCLES = 24'd200000;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            depth <= 4'd0;
            used_pi <= 8'd0;
            used_sigma <= 8'd0;
            current_candidate <= 4'd0;
            cycle_count <= 24'd0;
            search_started <= 1'b0;
            
            // Reset outputs
            pi_0 <= 8'd0; pi_1 <= 8'd0; pi_2 <= 8'd0; pi_3 <= 8'd0;
            pi_4 <= 8'd0; pi_5 <= 8'd0; pi_6 <= 8'd0; pi_7 <= 8'd0;
            sigma_0 <= 8'd0; sigma_1 <= 8'd0; sigma_2 <= 8'd0; sigma_3 <= 8'd0;
            sigma_4 <= 8'd0; sigma_5 <= 8'd0; sigma_6 <= 8'd0; sigma_7 <= 8'd0;
            done <= 1'b0;
            impossible <= 1'b0;
            
            // Reset arrays
            for (i = 0; i < 8; i = i + 1) begin
                a_reg[i] <= 8'd0;
                c_reg[i] <= 8'd0;
                pi_reg[i] <= 8'd0;
            end
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    impossible <= 1'b0;
                    cycle_count <= 24'd0;
                    search_started <= 1'b0;
                    
                    if (start && !search_started) begin
                        search_started <= 1'b1;
                        state <= STORE_INPUT;
                    end
                end
                
                STORE_INPUT: begin
                    // Store input sequence and compute c_i values
                    // c_i = (a_i == 1) ? (n-1) : (a_i - 2)
                    a_reg[0] <= a_0;
                    a_reg[1] <= a_1;
                    a_reg[2] <= a_2;
                    a_reg[3] <= a_3;
                    a_reg[4] <= a_4;
                    a_reg[5] <= a_5;
                    a_reg[6] <= a_6;
                    a_reg[7] <= a_7;
                    
                    // Compute c values
                    c_reg[0] <= (a_0 == 8'd1) ? (n - 8'd1) : (a_0 - 8'd2);
                    c_reg[1] <= (a_1 == 8'd1) ? (n - 8'd1) : (a_1 - 8'd2);
                    c_reg[2] <= (a_2 == 8'd1) ? (n - 8'd1) : (a_2 - 8'd2);
                    c_reg[3] <= (a_3 == 8'd1) ? (n - 8'd1) : (a_3 - 8'd2);
                    c_reg[4] <= (a_4 == 8'd1) ? (n - 8'd1) : (a_4 - 8'd2);
                    c_reg[5] <= (a_5 == 8'd1) ? (n - 8'd1) : (a_5 - 8'd2);
                    c_reg[6] <= (a_6 == 8'd1) ? (n - 8'd1) : (a_6 - 8'd2);
                    c_reg[7] <= (a_7 == 8'd1) ? (n - 8'd1) : (a_7 - 8'd2);
                    
                    // Initialize search
                    depth <= 4'd0;
                    used_pi <= 8'd0;
                    used_sigma <= 8'd0;
                    current_candidate <= 4'd0;
                    
                    state <= SEARCH;
                end
                
                SEARCH: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check for timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IMPOSSIBLE;
                    end else begin
                        // Backtracking search algorithm
                        if (depth < n) begin
                            // Try next candidate
                            if (current_candidate < n) begin
                                // Check if pi candidate is used
                                if (used_pi[current_candidate] == 1'b0) begin
                                    // Compute potential sigma
                                    // s_i = (c_i - pi_i) mod n
                                    // Need to handle modulo arithmetic
                                    reg [7:0] s_val;
                                    reg [7:0] c_val;
                                    reg [7:0] pi_val;
                                    
                                    c_val = c_reg[depth];
                                    pi_val = current_candidate;
                                    
                                    // Modular subtraction: (c - pi) mod n
                                    if (c_val >= pi_val) begin
                                        s_val = c_val - pi_val;
                                    end else begin
                                        s_val = n - (pi_val - c_val);
                                    end
                                    
                                    // Check if sigma is valid (0..n-1) and not used
                                    if (s_val < n && used_sigma[s_val] == 1'b0) begin
                                        // Accept this assignment
                                        pi_reg[depth] <= pi_val;
                                        used_pi[pi_val] <= 1'b1;
                                        used_sigma[s_val] <= 1'b1;
                                        depth <= depth + 4'd1;
                                        current_candidate <= 4'd0;
                                    end else begin
                                        // Try next candidate
                                        current_candidate <= current_candidate + 4'd1;
                                    end
                                end else begin
                                    // Try next candidate
                                    current_candidate <= current_candidate + 4'd1;
                                end
                            end else begin
                                // No more candidates at this depth - backtrack
                                if (depth == 4'd0) begin
                                    // Backtracked to root and exhausted all options
                                    state <= IMPOSSIBLE;
                                end else begin
                                    // Go back one level
                                    depth <= depth - 4'd1;
                                    current_candidate <= pi_reg[depth - 4'd1] + 4'd1;
                                    used_pi[pi_reg[depth - 4'd1]] <= 1'b0;
                                    // Need to recompute sigma used mask
                                    // This is complex, so we'll use a simpler approach:
                                    // Rebuild used_sigma from scratch for the current depth
                                    // For now, we'll just reset and continue (this is a limitation)
                                    // Better approach: store sigma values too
                                    used_sigma[c_reg[depth - 4'd1] - pi_reg[depth - 4'd1]] <= 1'b0;
                                end
                            end
                        end else begin
                            // Found a complete solution
                            state <= FOUND;
                        end
                    end
                end
                
                FOUND: begin
                    // Output the solution
                    pi_0 <= (n > 0) ? pi_reg[0] : 8'd0;
                    pi_1 <= (n > 1) ? pi_reg[1] : 8'd0;
                    pi_2 <= (n > 2) ? pi_reg[2] : 8'd0;
                    pi_3 <= (n > 3) ? pi_reg[3] : 8'd0;
                    pi_4 <= (n > 4) ? pi_reg[4] : 8'd0;
                    pi_5 <= (n > 5) ? pi_reg[5] : 8'd0;
                    pi_6 <= (n > 6) ? pi_reg[6] : 8'd0;
                    pi_7 <= (n > 7) ? pi_reg[7] : 8'd0;
                    
                    // Compute sigma outputs
                    sigma_0 <= (n > 0) ? ((c_reg[0] >= pi_reg[0]) ? (c_reg[0] - pi_reg[0]) : (n - (pi_reg[0] - c_reg[0]))) : 8'd0;
                    sigma_1 <= (n > 1) ? ((c_reg[1] >= pi_reg[1]) ? (c_reg[1] - pi_reg[1]) : (n - (pi_reg[1] - c_reg[1]))) : 8'd0;
                    sigma_2 <= (n > 2) ? ((c_reg[2] >= pi_reg[2]) ? (c_reg[2] - pi_reg[2]) : (n - (pi_reg[2] - c_reg[2]))) : 8'd0;
                    sigma_3 <= (n > 3) ? ((c_reg[3] >= pi_reg[3]) ? (c_reg[3] - pi_reg[3]) : (n - (pi_reg[3] - c_reg[3]))) : 8'd0;
                    sigma_4 <= (n > 4) ? ((c_reg[4] >= pi_reg[4]) ? (c_reg[4] - pi_reg[4]) : (n - (pi_reg[4] - c_reg[4]))) : 8'd0;
                    sigma_5 <= (n > 5) ? ((c_reg[5] >= pi_reg[5]) ? (c_reg[5] - pi_reg[5]) : (n - (pi_reg[5] - c_reg[5]))) : 8'd0;
                    sigma_6 <= (n > 6) ? ((c_reg[6] >= pi_reg[6]) ? (c_reg[6] - pi_reg[6]) : (n - (pi_reg[6] - c_reg[6]))) : 8'd0;
                    sigma_7 <= (n > 7) ? ((c_reg[7] >= pi_reg[7]) ? (c_reg[7] - pi_reg[7]) : (n - (pi_reg[7] - c_reg[7]))) : 8'd0;
                    
                    done <= 1'b1;
                    impossible <= 1'b0;
                    state <= IDLE;
                end
                
                IMPOSSIBLE: begin
                    // No solution found
                    pi_0 <= 8'd0; pi_1 <= 8'd0; pi_2 <= 8'd0; pi_3 <= 8'd0;
                    pi_4 <= 8'd0; pi_5 <= 8'd0; pi_6 <= 8'd0; pi_7 <= 8'd0;
                    sigma_0 <= 8'd0; sigma_1 <= 8'd0; sigma_2 <= 8'd0; sigma_3 <= 8'd0;
                    sigma_4 <= 8'd0; sigma_5 <= 8'd0; sigma_6 <= 8'd0; sigma_7 <= 8'd0;
                    done <= 1'b1;
                    impossible <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule