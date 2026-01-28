module FindMaxSubsequenceLength (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] strings_in [0:15][0:15],
    input wire [15:0] valid_inputs,
    output reg [5:0] result,
    output reg done
);

    // State machine states
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE = 3'd1;
    localparam [2:0] BUILD_GRAPH = 3'd2;
    localparam [2:0] COMPUTE_DP = 3'd3;
    localparam [2:0] FIND_MAX = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] i, j, k; // Loop counters
    reg [3:0] n; // Number of valid strings
    reg [3:0] len_i, len_j;
    reg [15:0] edge_matrix [0:15]; // Adjacency matrix
    reg [5:0] dp [0:15]; // DP array
    reg [5:0] dp_next [0:15];
    reg [5:0] current_max;
    reg match_prefix, match_suffix;
    reg [3:0] current_idx;
    reg [5:0] temp_max;

    // Helper: Find length of a string by finding first 0 or null
    function [3:0] get_len(input [3:0] idx);
        integer l;
        reg [5:0] char;
        begin
            get_len = 4'd0;
            for (l = 0; l < 16; l = l + 1) begin
                char = strings_in[idx][l];
                if (char == 6'd0) begin
                    get_len = l;
                    return;
                end
            end
            get_len = 4'd16;
        end
    endfunction

    // Helper: Check if string j starts with string i
    function starts_with(input [3:0] idx_i, idx_j);
        integer m;
        reg [5:0] c_i, c_j;
        begin
            starts_with = 1'b1;
            // Need to check up to length of i
            // But first check if len_j >= len_i
            if (get_len(idx_j) < get_len(idx_i)) begin
                starts_with = 1'b0;
            end else begin
                for (m = 0; m < 16; m = m + 1) begin
                    c_i = strings_in[idx_i][m];
                    if (c_i == 6'd0) begin
                        starts_with = 1'b1; // All matched
                        return;
                    end
                    c_j = strings_in[idx_j][m];
                    if (c_i != c_j) begin
                        starts_with = 1'b0;
                        return;
                    end
                end
            end
        end
    endfunction

    // Helper: Check if string j ends with string i
    function ends_with(input [3:0] idx_i, idx_j);
        integer offset, m;
        reg [5:0] c_i, c_j;
        begin
            ends_with = 1'b1;
            len_i = get_len(idx_i);
            len_j = get_len(idx_j);
            if (len_j < len_i) begin
                ends_with = 1'b0;
            end else begin
                offset = len_j - len_i;
                for (m = 0; m < len_i; m = m + 1) begin
                    c_i = strings_in[idx_i][m];
                    c_j = strings_in[idx_j][offset + m];
                    if (c_i != c_j) begin
                        ends_with = 1'b0;
                        return;
                    end
                end
            end
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 6'd0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            n <= 4'd0;
            current_max <= 6'd0;
            // Reset arrays
            for (int r = 0; r < 16; r = r + 1) begin
                edge_matrix[r] <= 16'd0;
                dp[r] <= 6'd0;
            end
        end else begin
            done <= 1'b0; // Default done low
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PARSE;
                        n <= 4'd0;
                        i <= 4'd0;
                    end
                end

                PARSE: begin
                    // Count valid strings
                    if (i < 16) begin
                        if (valid_inputs[i]) begin
                            n <= n + 1; // Just count, strings are already in the array
                        end
                        i <= i + 1;
                    end else begin
                        state <= BUILD_GRAPH;
                        i <= 4'd0;
                        j <= 4'd0;
                    end
                end

                BUILD_GRAPH: begin
                    // Build adjacency matrix for i < j
                    // Optimization: We only need edges i->j where i < j
                    if (i < n) begin
                        if (j < n) begin
                            if (i < j) begin
                                // Check condition
                                if (starts_with(i, j) && ends_with(i, j)) begin
                                    edge_matrix[i][j] <= 1'b1;
                                end else begin
                                    edge_matrix[i][j] <= 1'b0;
                                end
                            end
                            j <= j + 1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 1;
                        end
                    end else begin
                        state <= COMPUTE_DP;
                        i <= 4'd0;
                        j <= 4'd0;
                        // Initialize DP
                        for (int r = 0; r < 16; r = r + 1) begin
                            dp[r] <= 6'd1; // Each valid string is length 1
                        end
                    end
                end

                COMPUTE_DP: begin
                    // DP: dp[j] = max(dp[j], dp[i] + 1) if edge i->j
                    // Iterate i from 0 to n-1
                    if (i < n) begin
                        if (j < n) begin
                            if (i < j) begin
                                if (edge_matrix[i][j]) begin
                                    if (dp[i] + 6'd1 > dp[j]) begin
                                        dp[j] <= dp[i] + 6'd1;
                                    end
                                end
                            end
                            j <= j + 1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 1;
                        end
                    end else begin
                        state <= FIND_MAX;
                        i <= 4'd0;
                        current_max <= 6'd0;
                    end
                end

                FIND_MAX: begin
                    // Find max in dp array
                    if (i < n) begin
                        if (dp[i] > current_max) begin
                            current_max <= dp[i];
                        end
                        i <= i + 1;
                    end else begin
                        result <= current_max;
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule