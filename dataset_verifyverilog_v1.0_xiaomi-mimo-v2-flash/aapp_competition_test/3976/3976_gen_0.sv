module find_permutation_subsequence(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] m,
    input wire [3:0] p,
    input wire [5:0] a [0:15],
    input wire [5:0] b [0:15],
    output reg [3:0] result_count,
    output reg [3:0] result_positions [0:15],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] EXTRACT    = 3'd1;
    localparam [2:0] BUILD_HIST  = 3'd2;
    localparam [2:0] COMPARE    = 3'd3;
    localparam [2:0] SLIDE      = 3'd4;
    localparam [2:0] RECORD     = 3'd5;
    localparam [2:0] NEXT_Q     = 3'd6;
    localparam [2:0] FINISH     = 3'd7;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Internal registers
    reg [3:0] q_counter;           // Current q value (0 to p-1)
    reg [3:0] idx;                 // General index for loops
    reg [3:0] c_idx;               // Index for subsequence c
    reg [3:0] c_len;               // Length of current subsequence c
    reg [5:0] c [0:15];            // Current subsequence (max 16 elements)
    reg [3:0] hist_c [0:63];       // Histogram of c (6-bit values)
    reg [3:0] hist_b [0:63];       // Histogram of b (6-bit values)
    reg [3:0] window_start;        // Start index of window in c
    reg [3:0] result_idx;          // Index for result_positions array
    reg [3:0] hist_idx;            // Index for histogram comparison
    reg match_flag;                // Flag for histogram match
    reg [3:0] cycle_count;         // Cycle counter to prevent infinite loops
    localparam [3:0] MAX_CYCLES = 4'd15; // Maximum cycles per operation
    
    integer i;
    
    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_count <= 4'd0;
            q_counter <= 4'd0;
            idx <= 4'd0;
            c_idx <= 4'd0;
            c_len <= 4'd0;
            window_start <= 4'd0;
            result_idx <= 4'd0;
            hist_idx <= 4'd0;
            match_flag <= 1'b0;
            cycle_count <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                result_positions[i] <= 4'd0;
                c[i] <= 6'd0;
            end
            for (i = 0; i < 64; i = i + 1) begin
                hist_c[i] <= 4'd0;
                hist_b[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_count <= 4'd0;
                    q_counter <= 4'd0;
                    idx <= 4'd0;
                    c_idx <= 4'd0;
                    c_len <= 4'd0;
                    window_start <= 4'd0;
                    result_idx <= 4'd0;
                    hist_idx <= 4'd0;
                    match_flag <= 1'b0;
                    cycle_count <= 4'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        result_positions[i] <= 4'd0;
                        c[i] <= 6'd0;
                    end
                    for (i = 0; i < 64; i = i + 1) begin
                        hist_c[i] <= 4'd0;
                        hist_b[i] <= 4'd0;
                    end
                    if (start) begin
                        state <= EXTRACT;
                    end
                end
                
                EXTRACT: begin
                    // Build subsequence c from a with step p
                    if (c_idx < n) begin
                        if (c_idx >= q_counter) begin
                            if ((c_idx - q_counter) % p == 4'd0) begin
                                if (c_len < m) begin
                                    c[c_len] <= a[c_idx];
                                    c_len <= c_len + 4'd1;
                                end
                            end
                        end
                        c_idx <= c_idx + 4'd1;
                    end else begin
                        c_idx <= 4'd0;
                        if (c_len < m) begin
                            // Subsequence too short, skip
                            state <= NEXT_Q;
                        end else begin
                            // Build histogram of first m elements of c
                            state <= BUILD_HIST;
                        end
                    end
                end
                
                BUILD_HIST: begin
                    // Initialize histogram_c to 0
                    if (hist_idx < 64) begin
                        hist_c[hist_idx] <= 4'd0;
                        hist_idx <= hist_idx + 4'd1;
                    end else begin
                        hist_idx <= 4'd0;
                        if (idx < m) begin
                            // Count occurrences of each value in c (first m elements)
                            hist_c[c[idx]] <= hist_c[c[idx]] + 4'd1;
                            idx <= idx + 4'd1;
                        end else begin
                            idx <= 4'd0;
                            // Build histogram of b
                            if (hist_idx < 64) begin
                                hist_b[hist_idx] <= 4'd0;
                                hist_idx <= hist_idx + 4'd1;
                            end else begin
                                hist_idx <= 4'd0;
                                if (idx < m) begin
                                    hist_b[b[idx]] <= hist_b[b[idx]] + 4'd1;
                                    idx <= idx + 4'd1;
                                end else begin
                                    idx <= 4'd0;
                                    state <= COMPARE;
                                end
                            end
                        end
                    end
                end
                
                COMPARE: begin
                    // Compare histograms
                    if (hist_idx < 64) begin
                        if (hist_c[hist_idx] != hist_b[hist_idx]) begin
                            match_flag <= 1'b0;
                            hist_idx <= 64; // Skip remaining
                            state <= NEXT_Q;
                        end else begin
                            hist_idx <= hist_idx + 4'd1;
                        end
                    end else begin
                        // All histogram entries match
                        if (match_flag) begin
                            // Record q+1
                            state <= RECORD;
                        end else begin
                            // Check if we completed comparison without mismatch
                            if (hist_idx == 64 && idx == 0) begin
                                match_flag <= 1'b1;
                                hist_idx <= 4'd0;
                                idx <= m; // Skip b histogram build on next compare
                                state <= RECORD;
                            end else begin
                                state <= NEXT_Q;
                            end
                        end
                    end
                end
                
                RECORD: begin
                    if (result_idx < 16) begin
                        result_positions[result_idx] <= q_counter + 4'd1;
                        result_count <= result_count + 4'd1;
                        result_idx <= result_idx + 4'd1;
                        state <= NEXT_Q;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                NEXT_Q: begin
                    // Prepare for next window slide
                    if (window_start < (c_len - m)) begin
                        window_start <= window_start + 4'd1;
                        // Remove c[window_start] from histogram
                        hist_c[c[window_start]] <= hist_c[c[window_start]] - 4'd1;
                        // Add c[window_start + m] to histogram
                        if ((window_start + m) < c_len) begin
                            hist_c[c[window_start + m]] <= hist_c[c[window_start + m]] + 4'd1;
                        end
                        idx <= 4'd0;
                        state <= COMPARE;
                    end else begin
                        // Move to next q
                        if (q_counter < p - 4'd1) begin
                            q_counter <= q_counter + 4'd1;
                            c_idx <= 4'd0;
                            c_len <= 4'd0;
                            window_start <= 4'd0;
                            hist_idx <= 4'd0;
                            idx <= 4'd0;
                            match_flag <= 1'b0;
                            // Clear histogram_c
                            for (i = 0; i < 64; i = i + 1) begin
                                hist_c[i] <= 4'd0;
                            end
                            state <= EXTRACT;
                        end else begin
                            state <= FINISH;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule