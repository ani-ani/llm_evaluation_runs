module manuscript_reconstructor (
    input clk,
    input rst_n,
    input start,
    input [7:0] fragments [0:7],
    input [2:0] n,
    output reg [127:0] result,
    output reg [1:0] status,
    output reg done
);
    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT = 4'd1;
    localparam [3:0] CHECK_OVERLAP = 4'd2;
    localparam [3:0] BUILD_MATRIX = 4'd3;
    localparam [3:0] DP_INIT = 4'd4;
    localparam [3:0] DP_UPDATE = 4'd5;
    localparam [3:0] FIND_MAX = 4'd6;
    localparam [3:0] CHECK_AMBIGUOUS = 4'd7;
    localparam [3:0] TRACEBACK = 4'd8;
    localparam [3:0] CONSTRUCT = 4'd9;
    localparam [3:0] FINISH = 4'd10;

    reg [3:0] state;
    reg [3:0] next_state;
    
    // Fragment storage (packed ASCII)
    reg [63:0] frag_reg [0:7];
    reg [2:0] n_reg;
    
    // Adjacency matrix
    reg adj [0:7][0:7];
    
    // DP arrays
    reg [3:0] dp [0:7];      // Max path length ending at node
    reg [3:0] count [0:7];   // Number of paths of that length
    reg [2:0] prev [0:7];    // Previous node for traceback
    
    // Working variables
    reg [2:0] i, j, k, m;
    reg [3:0] overlap_len;
    reg [7:0] frag_i_suffix [0:7];
    reg [7:0] frag_j_prefix [0:7];
    reg match_found;
    reg [3:0] max_len;
    reg [2:0] max_node;
    reg ambiguous_found;
    reg [2:0] traceback_path [0:7];
    reg [2:0] path_idx;
    reg [2:0] current_node;
    
    // Result construction
    reg [7:0] result_buf [0:15];
    reg [3:0] result_idx;
    reg [3:0] total_len;
    
    // Cycle counter for safety
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            status <= 2'd0;
            result <= 128'd0;
            n_reg <= 3'd0;
            i <= 3'd0;
            j <= 3'd0;
            k <= 3'd0;
            m <= 3'd0;
            cycle_count <= 8'd0;
            // Initialize adjacency matrix
            for (k = 0; k < 8; k = k + 1) begin
                for (m = 0; m < 8; m = m + 1) begin
                    adj[k][m] <= 1'b0;
                end
            end
            // Initialize DP arrays
            for (k = 0; k < 8; k = k + 1) begin
                dp[k] <= 4'd0;
                count[k] <= 4'd0;
                prev[k] <= 3'd0;
            end
            // Initialize result buffer
            for (k = 0; k < 16; k = k + 1) begin
                result_buf[k] <= 8'd0;
            end
            // Initialize traceback path
            for (k = 0; k < 8; k = k + 1) begin
                traceback_path[k] <= 3'd0;
            end
            result_idx <= 4'd0;
            total_len <= 4'd0;
            max_len <= 4'd0;
            max_node <= 3'd0;
            ambiguous_found <= 1'b0;
            current_node <= 3'd0;
            overlap_len <= 4'd0;
            match_found <= 1'b0;
        end else begin
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    status <= 2'd0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        n_reg <= n;
                        // Store fragments
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < n) begin
                                frag_reg[i] <= {fragments[i][7:0], fragments[i][15:8], fragments[i][23:16], fragments[i][31:24], 
                                                fragments[i][39:32], fragments[i][47:40], fragments[i][55:48], fragments[i][63:56]};
                            end else begin
                                frag_reg[i] <= 64'd0;
                            end
                        end
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    i <= 3'd0;
                    j <= 3'd0;
                    // Reset adjacency matrix
                    for (k = 0; k < 8; k = k + 1) begin
                        for (m = 0; m < 8; m = m + 1) begin
                            adj[k][m] <= 1'b0;
                        end
                    end
                    state <= CHECK_OVERLAP;
                end
                
                CHECK_OVERLAP: begin
                    if (i < n_reg && j < n_reg) begin
                        if (i != j) begin
                            // Check overlap between fragment i and j
                            overlap_len <= 4'd0;
                            m <= 4'd0;
                            match_found <= 1'b0;
                            state <= BUILD_MATRIX;
                        end else begin
                            adj[i][j] <= 1'b0;
                            j <= j + 1;
                            if (j >= n_reg) begin
                                j <= 3'd0;
                                i <= i + 1;
                            end
                        end
                    end else begin
                        // Done building matrix
                        state <= DP_INIT;
                    end
                end
                
                BUILD_MATRIX: begin
                    // Check for overlap of length k (5 to 8)
                    // k is the overlap length we're testing
                    if (m < 4'd4) begin
                        // m=0: len 5, m=1: len 6, m=2: len 7, m=3: len 8
                        reg [3:0] len = m + 4'd5;
                        reg [3:0] idx;
                        reg temp_match;
                        temp_match = 1'b1;
                        
                        // Compare suffix of i (length len) with prefix of j (length len)
                        for (idx = 0; idx < 8; idx = idx + 1) begin
                            // Extract suffix character from i: position (8-len+idx)
                            // Extract prefix character from j: position idx
                            if (idx < len) begin
                                if (frag_reg[i][(7 - (8-len+idx))*8 +: 8] != frag_reg[j][(7-idx)*8 +: 8]) begin
                                    temp_match = 1'b0;
                                end
                            end
                        end
                        
                        if (temp_match && len >= 5) begin
                            adj[i][j] <= 1'b1;
                            match_found <= 1'b1;
                        end
                        
                        m <= m + 1;
                    end else begin
                        // Done checking this pair
                        j <= j + 1;
                        if (j >= n_reg) begin
                            j <= 3'd0;
                            i <= i + 1;
                        end
                        state <= CHECK_OVERLAP;
                    end
                end
                
                DP_INIT: begin
                    // Initialize DP for all nodes
                    for (k = 0; k < 8; k = k + 1) begin
                        if (k < n_reg) begin
                            dp[k] <= 4'd1;
                            count[k] <= 4'd1;
                            prev[k] <= 3'd0;
                        end else begin
                            dp[k] <= 4'd0;
                            count[k] <= 4'd0;
                            prev[k] <= 3'd0;
                        end
                    end
                    i <= 3'd0;
                    state <= DP_UPDATE;
                end
                
                DP_UPDATE: begin
                    // For each node i, update all reachable nodes j
                    if (i < n_reg) begin
                        if (adj[i][j]) begin
                            if (dp[i] + 4'd1 > dp[j]) begin
                                dp[j] <= dp[i] + 4'd1;
                                count[j] <= count[i];
                                prev[j] <= i;
                            end else if (dp[i] + 4'd1 == dp[j]) begin
                                count[j] <= count[j] + count[i];
                            end
                        end
                        j <= j + 1;
                        if (j >= n_reg) begin
                            j <= 3'd0;
                            i <= i + 1;
                        end
                    end else begin
                        state <= FIND_MAX;
                    end
                end
                
                FIND_MAX: begin
                    // Find the node with maximum dp value
                    max_len <= 4'd0;
                    max_node <= 3'd0;
                    i <= 3'd0;
                    state <= CHECK_AMBIGUOUS;
                end
                
                CHECK_AMBIGUOUS: begin
                    if (i < n_reg) begin
                        if (dp[i] > max_len) begin
                            max_len <= dp[i];
                            max_node <= i;
                        end
                        i <= i + 1;
                    end else begin
                        // Check if multiple paths to max_len
                        ambiguous_found <= 1'b0;
                        i <= 3'd0;
                        state <= TRACEBACK;
                    end
                end
                
                TRACEBACK: begin
                    // Check ambiguity at max node
                    if (count[max_node] > 4'd1) begin
                        ambiguous_found <= 1'b1;
                    end
                    
                    if (ambiguous_found || max_len == 4'd0) begin
                        status <= 2'd1; // AMBIGUOUS
                        state <= FINISH;
                    end else begin
                        // Traceback to build path
                        path_idx <= max_len - 4'd1;
                        current_node <= max_node;
                        for (k = 0; k < 8; k = k + 1) begin
                            traceback_path[k] <= 3'd0;
                        end
                        state <= CONSTRUCT;
                    end
                end
                
                CONSTRUCT: begin
                    // Traceback: current_node -> prev[current_node]
                    traceback_path[path_idx] <= current_node;
                    
                    if (path_idx == 4'd0) begin
                        // Done traceback, build result
                        result_idx <= 4'd0;
                        total_len <= 4'd0;
                        i <= 3'd0; // index in traceback_path
                        
                        // Initialize result buffer
                        for (k = 0; k < 16; k = k + 1) begin
                            result_buf[k] <= 8'd32; // space
                        end
                        state <= FINISH;
                        status <= 2'd0; // VALID
                    end else begin
                        current_node <= prev[current_node];
                        path_idx <= path_idx - 4'd1;
                    end
                end
                
                FINISH: begin
                    // Build the actual string
                    if (i < max_len) begin
                        reg [2:0] frag_id = traceback_path[i];
                        reg [3:0] frag_len = 8'd8; // Assume full length
                        
                        // Calculate overlap with previous
                        reg [3:0] overlap = 0;
                        if (i > 0) begin
                            reg [2:0] prev_id = traceback_path[i-1];
                            // Check which overlap exists
                            if (adj[prev_id][frag_id]) begin
                                // Find the overlap length (5-8)
                                for (m = 0; m < 4; m = m + 1) begin
                                    reg [3:0] len = m + 4'd5;
                                    reg [3:0] idx;
                                    reg temp_match = 1'b1;
                                    for (idx = 0; idx < 8; idx = idx + 1) begin
                                        if (idx < len) begin
                                            if (frag_reg[prev_id][(7 - (8-len+idx))*8 +: 8] != frag_reg[frag_id][(7-idx)*8 +: 8]) begin
                                                temp_match = 1'b0;
                                            end
                                        end
                                    end
                                    if (temp_match) overlap = len;
                                end
                            end
                        end
                        
                        // Copy fragment to result (skip overlap)
                        for (m = 0; m < 8; m = m + 1) begin
                            if (m >= overlap) begin
                                if (result_idx < 16) begin
                                    result_buf[result_idx] <= frag_reg[frag_id][(7-m)*8 +: 8];
                                    result_idx <= result_idx + 4'd1;
                                end
                            end
                        end
                        
                        i <= i + 1;
                    end else begin
                        // Pack result buffer into output
                        result[7:0] <= result_buf[0];
                        result[15:8] <= result_buf[1];
                        result[23:16] <= result_buf[2];
                        result[31:24] <= result_buf[3];
                        result[39:32] <= result_buf[4];
                        result[47:40] <= result_buf[5];
                        result[55:48] <= result_buf[6];
                        result[63:56] <= result_buf[7];
                        result[71:64] <= result_buf[8];
                        result[79:72] <= result_buf[9];
                        result[87:80] <= result_buf[10];
                        result[95:88] <= result_buf[11];
                        result[103:96] <= result_buf[12];
                        result[111:104] <= result_buf[13];
                        result[119:112] <= result_buf[14];
                        result[127:120] <= result_buf[15];
                        
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Safety timeout
            if (cycle_count >= MAX_CYCLES && state != IDLE) begin
                status <= 2'd2; // ERROR
                done <= 1'b1;
                state <= IDLE;
            end
        end
    end
endmodule