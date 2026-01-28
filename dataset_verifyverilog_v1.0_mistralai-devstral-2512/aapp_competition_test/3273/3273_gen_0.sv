module manuscript_reconstructor(
    input clk,
    input rst_n,
    input start,
    input [7:0][63:0] fragments,
    input [2:0] n,
    output reg [127:0] result,
    output reg [1:0] status,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_ADJ = 3'd1;
    localparam [2:0] COMPUTE_DP = 3'd2;
    localparam [2:0] FIND_MAX = 3'd3;
    localparam [2:0] CONSTRUCT = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Adjacency matrix (8x8)
    reg [7:0] adj [0:7];
    integer i, j, k;

    // DP arrays
    reg [2:0] dp [0:7];
    reg [2:0] count [0:7];

    // Max path tracking
    reg [2:0] max_dp;
    reg [2:0] max_node;
    reg ambiguous;

    // Reconstruction tracking
    reg [2:0] current_node;
    reg [2:0] prev_node;
    reg [2:0] path [0:7];
    reg [2:0] path_len;
    reg [127:0] reconstructed;
    reg [127:0] temp_result;

    // Overlap detection
    reg [7:0] overlap_len;
    reg [7:0] match_len;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 128'd0;
            status <= 2'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize adjacency matrix
            for (i = 0; i < 8; i = i + 1) begin
                adj[i] <= 8'd0;
            end

            // Initialize DP arrays
            for (i = 0; i < 8; i = i + 1) begin
                dp[i] <= 3'd1;
                count[i] <= 3'd1;
            end

            max_dp <= 3'd0;
            max_node <= 3'd0;
            ambiguous <= 1'b0;
            current_node <= 3'd0;
            prev_node <= 3'd0;
            path_len <= 3'd0;
            reconstructed <= 128'd0;
            temp_result <= 128'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE_ADJ;
                    end
                end

                COMPUTE_ADJ: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute adjacency matrix
                    for (i = 0; i < n; i = i + 1) begin
                        for (j = 0; j < n; j = j + 1) begin
                            if (i != j) begin
                                // Check overlaps from length 5 to 8
                                overlap_len = 5;
                                match_len = 0;
                                
                                for (k = 5; k <= 8; k = k + 1) begin
                                    // Compare suffix of i with prefix of j
                                    if (fragments[i][(8-k)*8-1:0] == fragments[j][(k-1)*8:0]) begin
                                        match_len = k;
                                    end
                                end
                                
                                if (match_len >= 5) begin
                                    adj[i][j] <= 1'b1;
                                end else begin
                                    adj[i][j] <= 1'b0;
                                end
                            end
                        end
                    end
                    
                    state <= COMPUTE_DP;
                end

                COMPUTE_DP: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Dynamic programming for longest path
                    for (i = 0; i < n; i = i + 1) begin
                        for (j = 0; j < n; j = j + 1) begin
                            if (adj[i][j]) begin
                                if (dp[i] + 3'd1 > dp[j]) begin
                                    dp[j] <= dp[i] + 3'd1;
                                    count[j] <= count[i];
                                end else if (dp[i] + 3'd1 == dp[j]) begin
                                    count[j] <= count[j] + count[i];
                                end
                            end
                        end
                    end
                    
                    state <= FIND_MAX;
                end

                FIND_MAX: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Find node with maximum dp value
                    max_dp <= 3'd0;
                    max_node <= 3'd0;
                    ambiguous <= 1'b0;
                    
                    for (i = 0; i < n; i = i + 1) begin
                        if (dp[i] > max_dp) begin
                            max_dp <= dp[i];
                            max_node <= i;
                            ambiguous <= 1'b0;
                        end else if (dp[i] == max_dp) begin
                            if (count[i] > 1) begin
                                ambiguous <= 1'b1;
                            end
                        end
                    end
                    
                    if (ambiguous) begin
                        status <= 2'd1;  // AMBIGUOUS
                        state <= FINISH;
                    end else begin
                        current_node <= max_node;
                        path_len <= 3'd0;
                        reconstructed <= 128'd0;
                        temp_result <= 128'd0;
                        state <= CONSTRUCT;
                    end
                end

                CONSTRUCT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Trace back to construct the path
                    path[path_len] <= current_node;
                    path_len <= path_len + 3'd1;
                    
                    // Find predecessor
                    prev_node <= 3'd0;
                    for (i = 0; i < n; i = i + 1) begin
                        if (adj[i][current_node] && dp[i] + 3'd1 == dp[current_node]) begin
                            prev_node <= i;
                            break;
                        end
                    end
                    
                    if (prev_node == 3'd0 || path_len >= n) begin
                        // Reconstruct the text
                        temp_result <= 128'd0;
                        for (i = path_len - 1; i >= 0; i = i - 1) begin
                            if (i == path_len - 1) begin
                                temp_result[7:0] <= fragments[path[i]][7:0];
                                temp_result[15:8] <= fragments[path[i]][15:8];
                                temp_result[23:16] <= fragments[path[i]][23:16];
                                temp_result[31:24] <= fragments[path[i]][31:24];
                                temp_result[39:32] <= fragments[path[i]][39:32];
                                temp_result[47:40] <= fragments[path[i]][47:40];
                                temp_result[55:48] <= fragments[path[i]][55:48];
                                temp_result[63:56] <= fragments[path[i]][63:56];
                            end else begin
                                // Find overlap length
                                overlap_len = 5;
                                for (k = 5; k <= 8; k = k + 1) begin
                                    if (fragments[path[i]][(8-k)*8-1:0] == temp_result[(k-1)*8:0]) begin
                                        overlap_len = k;
                                    end
                                end
                                
                                // Append non-overlapping part
                                if (overlap_len < 8) begin
                                    temp_result[127:8] <= temp_result[120:0];
                                    temp_result[7:0] <= fragments[path[i]][(8-overlap_len-1)*8-1:(8-overlap_len)*8];
                                end
                            end
                        end
                        
                        result <= temp_result;
                        status <= 2'd0;  // Valid Reconstruction
                        state <= FINISH;
                    end else begin
                        current_node <= prev_node;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
            
            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                status <= 2'd2;  // ERROR
                done <= 1'b1;
            end
        end
    end
endmodule