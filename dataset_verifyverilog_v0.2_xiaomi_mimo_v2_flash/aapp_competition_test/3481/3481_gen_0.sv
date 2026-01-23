module dj_polygon_gigs (
    input clk,
    input rst_n,
    input start,
    input [4:0] total_gigs,
    input [4:0] total_venues,
    input [31:0] dist_matrix [0:63],
    input [2:0] gig_venue [0:15],
    input [31:0] gig_start [0:15],
    input [31:0] gig_end [0:15],
    input [15:0] gig_money [0:15],
    output reg [15:0] max_earnings,
    output reg done
);

    // State definitions
    localparam IDLE = 4'd0;
    localparam SORT_INIT = 4'd1;
    localparam SORT_COMPARE = 4'd2;
    localparam SORT_UPDATE = 4'd3;
    localparam SORT_CHECK = 4'd4;
    localparam DP_INIT = 4'd5;
    localparam DP_OUTER = 4'd6;
    localparam DP_INNER = 4'd7;
    localparam DP_CALC = 4'd8;
    localparam DP_UPDATE = 4'd9;
    localparam DP_FINAL_MAX = 4'd10;
    localparam DONE = 4'd11;

    reg [3:0] state;
    
    // Registers for sorted gig data
    reg [2:0] s_gig_venue [0:15];
    reg [31:0] s_gig_start [0:15];
    reg [31:0] s_gig_end [0:15];
    reg [15:0] s_gig_money [0:15];
    
    // Temporary registers for sorting
    reg [2:0] temp_venue;
    reg [31:0] temp_start;
    reg [31:0] temp_end;
    reg [15:0] temp_money;
    
    // Sorter counters and flags
    reg [4:0] sort_i;
    reg [4:0] sort_j;
    reg sort_pass_done;
    reg sort_swapped;
    
    // DP array
    reg [15:0] dp [0:15];
    
    // DP loop counters
    reg [4:0] dp_i;
    reg [4:0] dp_j;
    
    // Computation registers
    reg [15:0] candidate_val;
    reg [15:0] current_max;
    
    // Time and distance calculation registers
    reg [31:0] time_j_plus_dist;
    reg [31:0] dist_val;
    
    // Transition flag
    reg transition_valid;
    
    // Variables for max accumulation
    reg [4:0] max_idx;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_earnings <= 16'd0;
            done <= 1'b0;
            sort_i <= 5'd0;
            sort_j <= 5'd0;
            sort_swapped <= 1'b0;
            dp_i <= 5'd0;
            dp_j <= 5'd0;
            max_idx <= 5'd0;
            // Reset sorted arrays (optional but good practice)
            // Arrays are not reset per se, but managed by state
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SORT_INIT;
                    end else begin
                        state <= IDLE;
                    end
                end

                SORT_INIT: begin
                    // Copy input arrays to sorted arrays
                    // Since we can't loop in hardware implicitly, we do it sequentially or use a counter
                    // Using sort_i as copy counter
                    if (sort_i < total_gigs) begin
                        s_gig_venue[sort_i] <= gig_venue[sort_i];
                        s_gig_start[sort_i] <= gig_start[sort_i];
                        s_gig_end[sort_i] <= gig_end[sort_i];
                        s_gig_money[sort_i] <= gig_money[sort_i];
                        sort_i <= sort_i + 1'b1;
                        state <= SORT_INIT;
                    end else begin
                        sort_i <= 5'd0;
                        sort_j <= 5'd0;
                        sort_swapped <= 1'b0;
                        state <= SORT_COMPARE;
                    end
                end

                SORT_COMPARE: begin
                    // Bubble sort pass
                    // We need to compare adjacent elements (j and j+1)
                    // Based on end time ascending
                    if (sort_j < total_gigs - 1 - sort_i) begin
                        // Check if swap needed (s_gig_end[j] > s_gig_end[j+1])
                        if (s_gig_end[sort_j] > s_gig_end[sort_j + 1]) begin
                            // Swap needed
                            temp_venue <= s_gig_venue[sort_j];
                            temp_start <= s_gig_start[sort_j];
                            temp_end <= s_gig_end[sort_j];
                            temp_money <= s_gig_money[sort_j];
                            sort_swapped <= 1'b1;
                            state <= SORT_UPDATE;
                        end else begin
                            sort_j <= sort_j + 1'b1;
                            state <= SORT_COMPARE;
                        end
                    end else begin
                        // End of pass
                        if (sort_swapped) begin
                            sort_i <= 5'd0;
                            sort_j <= 5'd0;
                            sort_swapped <= 1'b0;
                            state <= SORT_COMPARE; // Continue passes
                        end else begin
                            state <= DP_INIT;
                        end
                    end
                end

                SORT_UPDATE: begin
                    // Perform swap
                    s_gig_venue[sort_j] <= s_gig_venue[sort_j + 1];
                    s_gig_start[sort_j] <= s_gig_start[sort_j + 1];
                    s_gig_end[sort_j] <= s_gig_end[sort_j + 1];
                    s_gig_money[sort_j] <= s_gig_money[sort_j + 1];
                    
                    s_gig_venue[sort_j + 1] <= temp_venue;
                    s_gig_start[sort_j + 1] <= temp_start;
                    s_gig_end[sort_j + 1] <= temp_end;
                    s_gig_money[sort_j + 1] <= temp_money;
                    
                    sort_j <= sort_j + 1'b1;
                    state <= SORT_COMPARE;
                end

                SORT_CHECK: begin
                    // Not used, merged into SORT_COMPARE
                    state <= SORT_COMPARE;
                end

                DP_INIT: begin
                    // Initialize dp array to 0
                    if (dp_i < total_gigs) begin
                        dp[dp_i] <= 16'd0;
                        dp_i <= dp_i + 1'b1;
                        state <= DP_INIT;
                    end else begin
                        dp_i <= 5'd0; // i index for outer loop
                        dp_j <= 5'd0; // j index for inner loop
                        state <= DP_OUTER;
                    end
                end

                DP_OUTER: begin
                    // Outer loop: i from 0 to N-1
                    if (dp_i < total_gigs) begin
                        // Calculate start max_val for this i
                        // Option A: Allow skipping gig i (earnings 0)
                        // Option B: Must attend gig i (earnings money[i] if reachable from start)
                        // We set current_max = money[i] (taking it alone is base)
                        current_max <= s_gig_money[dp_i];
                        dp_j <= 5'd0; // Reset j
                        state <= DP_INNER;
                    end else begin
                        state <= DP_FINAL_MAX;
                    end
                end

                DP_INNER: begin
                    // Inner loop: j from 0 to i-1
                    if (dp_j < dp_i) begin
                        // Check time constraint: end_time[j] + dist <= start_time[i]
                        // Calculate dist
                        dist_val <= dist_matrix[{s_gig_venue[dp_j], s_gig_venue[dp_i]}];
                        state <= DP_CALC;
                    end else begin
                        // Inner loop finished, update dp[i]
                        dp[dp_i] <= current_max;
                        dp_i <= dp_i + 1'b1;
                        state <= DP_OUTER;
                    end
                end

                DP_CALC: begin
                    // Compute time_j_plus_dist and check validity
                    // Addition
                    time_j_plus_dist <= s_gig_end[dp_j] + dist_val;
                    
                    // Check if distance is infinity (MAX)
                    // If dist_val == 32'hFFFF_FFFF, don't consider (or handle overflow)
                    // Also check time constraint
                    transition_valid <= 1'b0; // Default invalid
                    
                    if (dist_val != 32'hFFFF_FFFF) begin
                        // Wait one cycle for addition
                        state <= DP_UPDATE;
                    end else begin
                        // Invalid distance, skip
                        dp_j <= dp_j + 1'b1;
                        state <= DP_INNER;
                    end
                end

                DP_UPDATE: begin
                    // Check time constraint using the computed value
                    if (time_j_plus_dist <= s_gig_start[dp_i]) begin
                        // Valid transition
                        // candidate = dp[j] + money[i]
                        candidate_val <= dp[dp_j] + s_gig_money[dp_i];
                        transition_valid <= 1'b1;
                    end else begin
                        transition_valid <= 1'b0;
                    end
                    
                    // Compare and update max
                    if (transition_valid && (candidate_val > current_max)) begin
                        current_max <= candidate_val;
                    end
                    
                    dp_j <= dp_j + 1'b1;
                    state <= DP_INNER;
                end

                DP_FINAL_MAX: begin
                    // Find max in dp array
                    if (max_idx < total_gigs) begin
                        if (dp[max_idx] > max_earnings) begin
                            max_earnings <= dp[max_idx];
                        end
                        max_idx <= max_idx + 1'b1;
                        state <= DP_FINAL_MAX;
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end else begin
                        state <= DONE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
