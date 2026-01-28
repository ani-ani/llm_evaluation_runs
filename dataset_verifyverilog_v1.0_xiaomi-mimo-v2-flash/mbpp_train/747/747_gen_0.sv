module LCS_3D (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] len_a,
    input wire [2:0] len_b,
    input wire [2:0] len_c,
    input wire [7:0] str_a [0:7],
    input wire [7:0] str_b [0:7],
    input wire [7:0] str_c [0:7],
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT_DP   = 3'd1;
    localparam [2:0] LOAD_STR  = 3'd2;
    localparam [2:0] COMPUTE   = 3'd3;
    localparam [2:0] RESULT    = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    // Control Registers
    reg [2:0] state, next_state;
    reg [2:0] i, j, k;
    reg [2:0] idx_i, idx_j, idx_k;
    reg [2:0] a_len, b_len, c_len;
    reg [7:0] char_a, char_b, char_c;
    reg match_flag;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // DP Table: [9][9][9] of 4-bit values (0-8)
    reg [3:0] dp [0:8][0:8][0:8];
    
    // Temp registers for computation
    reg [3:0] max_val;
    reg [3:0] val1, val2, val3;

    // State transition logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INIT_DP;
            end
            INIT_DP: begin
                if (i == 3'd8 && j == 3'd8 && k == 3'd8) next_state = LOAD_STR;
            end
            LOAD_STR: begin
                next_state = COMPUTE;
            end
            COMPUTE: begin
                if (i > a_len || j > b_len || k > c_len) begin
                    next_state = RESULT;
                end
            end
            RESULT: begin
                next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            i <= 3'd0;
            j <= 3'd0;
            k <= 3'd0;
            idx_i <= 3'd0;
            idx_j <= 3'd0;
            idx_k <= 3'd0;
            a_len <= 3'd0;
            b_len <= 3'd0;
            c_len <= 3'd0;
            char_a <= 8'd0;
            char_b <= 8'd0;
            char_c <= 8'd0;
            cycle_count <= 8'd0;
            match_flag <= 1'b0;
            // Initialize DP table to 0
            for (idx_i = 0; idx_i < 9; idx_i = idx_i + 1) begin
                for (idx_j = 0; idx_j < 9; idx_j = idx_j + 1) begin
                    for (idx_k = 0; idx_k < 9; idx_k = idx_k + 1) begin
                        dp[idx_i][idx_j][idx_k] <= 4'd0;
                    end
                end
            end
        end else begin
            state <= next_state;
            done <= 1'b0;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    cycle_count <= 8'd0;
                    done <= 1'b0;
                    if (start) begin
                        a_len <= len_a;
                        b_len <= len_b;
                        c_len <= len_c;
                        i <= 3'd0;
                        j <= 3'd0;
                        k <= 3'd0;
                    end
                end

                INIT_DP: begin
                    // Initialize all DP cells to 0
                    if (i < 3'd8) begin
                        i <= i + 3'd1;
                        j <= 3'd0;
                        k <= 3'd0;
                    end else if (j < 3'd8) begin
                        j <= j + 3'd1;
                        k <= 3'd0;
                    end else if (k < 3'd8) begin
                        k <= k + 3'd1;
                    end
                    // Set all to 0 (reset handles this, but explicit for clarity)
                    dp[i][j][k] <= 4'd0;
                end

                LOAD_STR: begin
                    // Load characters for indices i,j,k
                    // Note: Strings are 0-indexed, indices i,j,k are 1-indexed in algorithm
                    if (i > 3'd0 && i <= a_len) begin
                        char_a <= str_a[i-3'd1];
                    end
                    if (j > 3'd0 && j <= b_len) begin
                        char_b <= str_b[j-3'd1];
                    end
                    if (k > 3'd0 && k <= c_len) begin
                        char_c <= str_c[k-3'd1];
                    end
                    i <= 3'd0;
                    j <= 3'd0;
                    k <= 3'd1;
                end

                COMPUTE: begin
                    // Iterate through i, j, k (1 to len)
                    // Check if characters match
                    match_flag <= 1'b0;
                    if (i > 3'd0 && j > 3'd0 && k > 3'd0 && 
                        i <= a_len && j <= b_len && k <= c_len &&
                        str_a[i-3'd1] == str_b[j-3'd1] && 
                        str_b[j-3'd1] == str_c[k-3'd1]) begin
                        match_flag <= 1'b1;
                    end
                    
                    // Calculate values for max computation
                    // dp[i-1][j][k], dp[i][j-1][k], dp[i][j][k-1]
                    val1 <= (i > 3'd0) ? dp[i-3'd1][j][k] : 4'd0;
                    val2 <= (j > 3'd0) ? dp[i][j-3'd1][k] : 4'd0;
                    val3 <= (k > 3'd0) ? dp[i][j][k-3'd1] : 4'd0;

                    // Determine max of three
                    if (val1 >= val2 && val1 >= val3) max_val <= val1;
                    else if (val2 >= val1 && val2 >= val3) max_val <= val2;
                    else max_val <= val3;

                    // Update DP table
                    if (match_flag) begin
                        dp[i][j][k] <= dp[i-3'd1][j-3'd1][k-3'd1] + 4'd1;
                    end else begin
                        dp[i][j][k] <= max_val;
                    end

                    // Increment indices
                    if (i < a_len) begin
                        i <= i + 3'd1;
                        j <= 3'd0;
                        k <= 3'd0;
                    end else if (j < b_len) begin
                        j <= j + 3'd1;
                        k <= 3'd0;
                        i <= 3'd0;
                    end else if (k < c_len) begin
                        k <= k + 3'd1;
                        i <= 3'd0;
                        j <= 3'd0;
                    end
                end

                RESULT: begin
                    // Read result from dp[len_a][len_b][len_c]
                    result <= {4'd0, dp[a_len][b_len][c_len][3:0]};
                end

                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule