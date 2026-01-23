module lcs_permutations(
    input clk,
    input rst_n,
    input start,
    input [2:0] n,           // number of strings (1-6)
    input [3:0] k,           // number of letters (1-8)
    input [31:0] strings_in, // serialized input: 8 chars packed into 32 bits (4 bits per char)
    input [2:0] str_idx,     // current string index for input
    output reg [3:0] result, // length of LCS
    output reg done,
    output reg ready_for_next // signal to send next string
);

    // State definitions
    localparam IDLE = 3'd0;
    localparam INPUT_STRINGS = 3'd1;
    localparam BUILD_ORDERING = 3'd2;
    localparam COMPUTE_LCS = 3'd3;
    localparam OUTPUT_RESULT = 3'd4;
    
    reg [2:0] state;
    reg [2:0] input_counter;
    reg [2:0] current_str;
    reg [3:0] i, j, idx;
    reg [2:0] iter_k;
    
    // Storage for strings
    reg [31:0] strings [0:5];
    
    // Position arrays: pos[str_idx][char_value] = position (1-based)
    reg [3:0] pos [0:5][0:8];
    
    // DAG adjacency matrix: can_precede[i][j] = 1 if char i appears before char j in ALL strings
    reg can_precede [0:8][0:8];
    
    // DP for longest path: dp[char] = longest chain ending at this char
    reg [3:0] dp [0:8];
    reg [3:0] dp_next [0:8];
    reg [3:0] max_lcs;
    reg [3:0] temp_max;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            ready_for_next <= 0;
            input_counter <= 0;
            current_str <= 0;
            i <= 0;
            j <= 0;
            idx <= 0;
            max_lcs <= 0;
            iter_k <= 0;
            // Initialize can_precede to 1
            for (i = 0; i <= 8; i = i + 1) begin
                for (j = 0; j <= 8; j = j + 1) begin
                    can_precede[i][j] <= 1;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= INPUT_STRINGS;
                        input_counter <= 0;
                        ready_for_next <= 1;
                        // Reset can_precede
                        for (i = 0; i <= 8; i = i + 1) begin
                            for (j = 0; j <= 8; j = j + 1) begin
                                can_precede[i][j] <= 1;
                            end
                        end
                    end
                end
                
                INPUT_STRINGS: begin
                    ready_for_next <= 0;
                    if (input_counter < n) begin
                        if (str_idx == input_counter) begin
                            strings[input_counter] <= strings_in;
                            // Parse and store positions
                            for (idx = 0; idx < 8; idx = idx + 1) begin
                                if (idx < k) begin
                                    pos[input_counter][strings_in[idx*4 +: 4]] <= idx + 1;
                                end
                            end
                            input_counter <= input_counter + 1;
                            ready_for_next <= 1;
                            if (input_counter + 1 >= n) begin
                                ready_for_next <= 0;
                                state <= BUILD_ORDERING;
                                current_str <= 0;
                                i <= 1;
                                j <= 1;
                            end
                        end
                    end
                end
                
                BUILD_ORDERING: begin
                    // Build can_precede matrix
                    if (current_str < n) begin
                        if (i <= k && j <= k) begin
                            if (i != j) begin
                                if (pos[current_str][i] >= pos[current_str][j]) begin
                                    can_precede[i][j] <= 0;
                                end
                            end
                            // Advance j
                            if (j == k) begin
                                j <= 1;
                                if (i == k) begin
                                    i <= 1;
                                    current_str <= current_str + 1;
                                end else begin
                                    i <= i + 1;
                                end
                            end else begin
                                j <= j + 1;
                            end
                        end else begin
                            // Skip diagonal
                            if (i <= k) begin
                                if (j == k) begin
                                    j <= 1;
                                    i <= i + 1;
                                end else begin
                                    j <= j + 1;
                                end
                            end else begin
                                i <= 1;
                                current_str <= current_str + 1;
                            end
                        end
                    end else begin
                        state <= COMPUTE_LCS;
                        i <= 1;
                        j <= 1;
                        iter_k <= 0;
                        // Initialize dp
                        for (idx = 1; idx <= 8; idx = idx + 1) begin
                            dp[idx] <= 1;
                        end
                    end
                end
                
                COMPUTE_LCS: begin
                    // Longest path in DAG - 8 iterations
                    if (iter_k < 8) begin
                        if (i <= k) begin
                            if (j <= k) begin
                                if (can_precede[j][i] && (dp[j] + 1 > dp[i])) begin
                                    dp[i] <= dp[j] + 1;
                                end
                                j <= j + 1;
                            end else begin
                                j <= 1;
                                i <= i + 1;
                            end
                        end else begin
                            i <= 1;
                            iter_k <= iter_k + 1;
                        end
                    end else begin
                        // Find maximum
                        max_lcs <= dp[1];
                        i <= 2;
                        temp_max <= dp[1];
                        state <= OUTPUT_RESULT;
                    end
                end
                
                OUTPUT_RESULT: begin
                    if (i <= k) begin
                        if (dp[i] > temp_max) begin
                            temp_max <= dp[i];
                        end
                        i <= i + 1;
                    end else begin
                        result <= temp_max;
                        done <= 1;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule