module VerifyMerge(
    input clk,
    input rst_n,
    input start,
    input [4:0] s [0:15],
    input [4:0] s1 [0:15],
    input [4:0] s2 [0:15],
    input [3:0] len_s,
    input [3:0] len_s1,
    input [3:0] len_s2,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT_DP   = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] CHECK     = 3'd3;
    localparam [2:0] FINISH    = 3'd4;

    // Internal registers for DP table
    // dp[i][j] means s1[0:i-1] and s2[0:j-1] can form s[0:i+j-1]
    // We only need previous row for computation, but for simplicity and
    // given size constraints, we'll store the full 16x16 grid.
    // Each entry is a 1-bit boolean.
    reg dp [0:15] [0:15];
    
    // Counters
    reg [3:0] i;
    reg [3:0] j;
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Temporary storage for DP computation
    reg dp_from_up;
    reg dp_from_left;
    
    // Match flags
    reg match_up;
    reg match_left;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT_DP;
                else
                    next_state = IDLE;
            end
            INIT_DP: begin
                next_state = COMPUTE;
            end
            COMPUTE: begin
                if (i > len_s1 || j > len_s2)
                    next_state = CHECK;
                else
                    next_state = COMPUTE;
            end
            CHECK: begin
                next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Main sequential logic
    integer row_idx, col_idx;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            // Initialize DP table
            for (row_idx = 0; row_idx < 16; row_idx = row_idx + 1) begin
                for (col_idx = 0; col_idx < 16; col_idx = col_idx + 1) begin
                    dp[row_idx][col_idx] <= 1'b0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    if (start) begin
                        // Start triggered, next state will be INIT_DP
                        // (Logic handled by next_state logic)
                    end
                end

                INIT_DP: begin
                    // Initialize DP table base cases
                    // dp[0][0] = 1 (empty strings form empty string)
                    // This is handled in the loop below
                    
                    // Initialize row 0: dp[0][j] - only using s2
                    // dp[0][j] is valid if s2[0:j-1] == s[0:j-1]
                    // Initialize column 0: dp[i][0] - only using s1
                    // dp[i][0] is valid if s1[0:i-1] == s[0:i-1]
                    
                    // We do this initialization in one cycle for simplicity
                    // Base case: dp[0][0] = 1
                    dp[0][0] <= 1'b1;
                    
                    // Initialize first row (j from 1 to len_s2)
                    // Using a loop for clarity, though unrolled is faster
                    for (col_idx = 1; col_idx < 16; col_idx = col_idx + 1) begin
                        if (col_idx <= len_s2) begin
                            // Check if s2[col_idx-1] matches s[col_idx-1]
                            if (dp[0][col_idx-1] && (s2[col_idx-1] == s[col_idx-1]))
                                dp[0][col_idx] <= 1'b1;
                            else
                                dp[0][col_idx] <= 1'b0;
                        end else begin
                            dp[0][col_idx] <= 1'b0;
                        end
                    end
                    
                    // Initialize first column (i from 1 to len_s1)
                    for (row_idx = 1; row_idx < 16; row_idx = row_idx + 1) begin
                        if (row_idx <= len_s1) begin
                            // Check if s1[row_idx-1] matches s[row_idx-1]
                            if (dp[row_idx-1][0] && (s1[row_idx-1] == s[row_idx-1]))
                                dp[row_idx][0] <= 1'b1;
                            else
                                dp[row_idx][0] <= 1'b0;
                        end else begin
                            dp[row_idx][0] <= 1'b0;
                        end
                    end
                    
                    // Reset remaining cells
                    for (row_idx = 1; row_idx < 16; row_idx = row_idx + 1) begin
                        for (col_idx = 1; col_idx < 16; col_idx = col_idx + 1) begin
                            dp[row_idx][col_idx] <= 1'b0;
                        end
                    end
                    
                    // Set counters for computation loop
                    i <= 4'd1;
                    j <= 4'd1;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check match conditions
                    // Current character in s is at index (i-1)+(j-1) = i+j-2
                    // s1 character is at index i-1
                    // s2 character is at index j-1
                    
                    // Avoid out of bounds access logic
                    // If i+j-2 >= len_s, it's an invalid state, but we check range below
                    
                    match_up = 1'b0;
                    match_left = 1'b0;
                    dp_from_up = 1'b0;
                    dp_from_left = 1'b0;
                    
                    if (i <= len_s1) begin
                        // Check match with s1[i-1]
                        if ((i+j-2) < 16 && (i-1) < 16 && (i+j-2) < len_s) begin
                            if (s[i+j-2] == s1[i-1]) begin
                                match_up = 1'b1;
                                dp_from_up = dp[i-1][j];
                            end
                        end
                    end
                    
                    if (j <= len_s2) begin
                        // Check match with s2[j-1]
                        if ((i+j-2) < 16 && (j-1) < 16 && (i+j-2) < len_s) begin
                            if (s[i+j-2] == s2[j-1]) begin
                                match_left = 1'b1;
                                dp_from_left = dp[i][j-1];
                            end
                        end
                    end
                    
                    // Compute DP value
                    if (match_up && dp_from_up) begin
                        dp[i][j] <= 1'b1;
                    end else if (match_left && dp_from_left) begin
                        dp[i][j] <= 1'b1;
                    end else begin
                        dp[i][j] <= 1'b0;
                    end
                    
                    // Increment counters
                    if (j < len_s2 + 1) begin
                        if (j < 15) begin
                            j <= j + 4'd1;
                        end else begin
                            // Row complete, move to next column
                            j <= 4'd1;
                            if (i < len_s1 + 1) begin
                                if (i < 15)
                                    i <= i + 4'd1;
                                else
                                    i <= i; // Should not happen if logic is correct
                            end
                        end
                    end else begin
                        j <= 4'd1;
                        if (i < len_s1 + 1) begin
                            if (i < 15)
                                i <= i + 4'd1;
                        end
                    end
                    
                    // Check exit condition: reached end of relevant DP table
                    // We need to compute up to i = len_s1 + 1, j = len_s2 + 1 (exclusive)
                    // Actually loop logic: i runs 1 to len_s1, j runs 1 to len_s2
                    // Condition: if i > len_s1 or j > len_s2
                    // Since we increment at end, check if we should stop.
                    // If i > len_s1, we are done with rows.
                    // If j > len_s2, we are done with current row.
                    // If we just finished (len_s1, len_s2), next cycle will trigger transition.
                    
                end

                CHECK: begin
                    // Result is in dp[len_s1][len_s2]
                    // Check if lengths match first
                    if ((len_s1 + len_s2) == len_s) begin
                        if (len_s1 <= 15 && len_s2 <= 15) begin
                            valid <= dp[len_s1][len_s2];
                        end else begin
                            valid <= 1'b0;
                        end
                    end else begin
                        valid <= 1'b0;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                    valid <= 1'b0;
                    done <= 1'b0;
                end
            endcase
            
            // Manual transition to IDLE in FINISH state
            if (state == FINISH) begin
                state <= IDLE;
            end else begin
                state <= next_state;
            end
            
            // Safety timeout
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
                valid <= 1'b0;
                state <= FINISH;
            end
        end
    end

endmodule