module LongestCommonSubsequenceWithVirus(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] s1 [0:15],
    input wire [7:0] s2 [0:15],
    input wire [7:0] virus [0:7],
    input wire [3:0] len1,
    input wire [3:0] len2,
    input wire [3:0] len3,
    output reg [7:0] result [0:15],
    output reg [3:0] result_len,
    output reg done
);

// State machine states
localparam [3:0] IDLE       = 4'd0;
localparam [3:0] COMPUTE_KMP = 4'd1;
localparam [3:0] INIT_DP    = 4'd2;
localparam [3:0] DP_LOOP_I  = 4'd3;
localparam [3:0] DP_LOOP_J  = 4'd4;
localparam [3:0] DP_LOOP_K  = 4'd5;
localparam [3:0] DP_TRANS   = 4'd6;
localparam [3:0] FIND_MAX   = 4'd7;
localparam [3:0] RECONSTRUCT = 4'd8;
localparam [3:0] OUTPUT_RESULT = 4'd9;
localparam [3:0] FINISH     = 4'd10;

reg [3:0] state, next_state;

// KMP next table (size 9 for virus length up to 8)
reg [3:0] kmp_next [0:8];
reg [3:0] kmp_idx;

// DP arrays (4-bit length storage)
reg [3:0] F [0:16][0:16][0:8];
reg [15:0] parent [0:16][0:16][0:8];  // packed: {prev_i[3:0], prev_j[3:0], prev_k[3:0], matched[1:0]}

// Loop counters
reg [3:0] i, j, k;
reg [3:0] next_k;
reg [3:0] max_val;
reg [3:0] max_i, max_j, max_k;

// Reconstruction variables
reg [3:0] recon_i, recon_j, recon_k;
reg [3:0] recon_idx;
reg [15:0] recon_path [0:16];  // store matched characters
reg [3:0] path_len;

// Cycle counter for timeout prevention
reg [13:0] cycle_count;  // up to 16383 cycles
localparam [13:0] MAX_CYCLES = 14'd10000;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result_len <= 4'd0;
        kmp_idx <= 4'd0;
        i <= 4'd0;
        j <= 4'd0;
        k <= 4'd0;
        next_k <= 4'd0;
        max_val <= 4'd0;
        max_i <= 4'd0;
        max_j <= 4'd0;
        max_k <= 4'd0;
        recon_i <= 4'd0;
        recon_j <= 4'd0;
        recon_k <= 4'd0;
        recon_idx <= 4'd0;
        path_len <= 4'd0;
        cycle_count <= 14'd0;
        // Initialize result buffer
        for (int r = 0; r < 16; r = r + 1) begin
            result[r] <= 8'd0;
            recon_path[r] <= 16'd0;
        end
        // Initialize kmp_next table
        for (int n = 0; n < 9; n = n + 1) begin
            kmp_next[n] <= 4'd0;
        end
        // Initialize DP arrays
        for (int di = 0; di < 17; di = di + 1) begin
            for (int dj = 0; dj < 17; dj = dj + 1) begin
                for (int dk = 0; dk < 9; dk = dk + 1) begin
                    F[di][dj][dk] <= 4'd0;
                    parent[di][dj][dk] <= 16'd0;
                end
            end
        end
    end else begin
        cycle_count <= cycle_count + 14'd1;
        case (state)
            IDLE: begin
                done <= 1'b0;
                result_len <= 4'd0;
                cycle_count <= 14'd0;
                if (start) begin
                    state <= COMPUTE_KMP;
                    kmp_idx <= 4'd0;
                end
            end
            
            COMPUTE_KMP: begin
                // Compute KMP next table for virus string
                if (kmp_idx == 4'd0) begin
                    kmp_next[0] <= 4'd0;
                    kmp_idx <= 4'd1;
                end else if (kmp_idx <= len3) begin
                    if (kmp_idx == 4'd1) begin
                        kmp_next[1] <= 4'd0;
                    end else begin
                        // Find longest proper prefix which is also suffix
                        reg [3:0] j_kmp;
                        reg [3:0] len_val;
                        len_val = 4'd0;
                        for (j_kmp = 4'd1; j_kmp < kmp_idx; j_kmp = j_kmp + 4'd1) begin
                            // Check if prefix matches suffix
                            reg match;
                            match = 1'b1;
                            for (int p = 0; p < j_kmp; p = p + 1) begin
                                if (virus[p] != virus[kmp_idx - j_kmp + p]) begin
                                    match = 1'b0;
                                end
                            end
                            if (match) begin
                                len_val = j_kmp;
                            end
                        end
                        kmp_next[kmp_idx] <= len_val;
                    end
                    kmp_idx <= kmp_idx + 4'd1;
                end else begin
                    state <= INIT_DP;
                end
            end
            
            INIT_DP: begin
                // Initialize F[0][0][0] = 0 (already set in reset)
                state <= DP_LOOP_I;
                i <= 4'd0;
            end
            
            DP_LOOP_I: begin
                if (i <= len1) begin
                    j <= 4'd0;
                    state <= DP_LOOP_J;
                end else begin
                    state <= FIND_MAX;
                end
            end
            
            DP_LOOP_J: begin
                if (j <= len2) begin
                    k <= 4'd0;
                    state <= DP_LOOP_K;
                end else begin
                    i <= i + 4'd1;
                    state <= DP_LOOP_I;
                end
            end
            
            DP_LOOP_K: begin
                if (k < len3) begin
                    state <= DP_TRANS;
                end else begin
                    j <= j + 4'd1;
                    state <= DP_LOOP_J;
                end
            end
            
            DP_TRANS: begin
                // Skip s1[i]
                if (F[i+1][j][k] < F[i][j][k]) begin
                    F[i+1][j][k] <= F[i][j][k];
                    parent[i+1][j][k] <= {i, j, k, 2'b00};  // from (i,j,k), no match
                end
                
                // Skip s2[j]
                if (F[i][j+1][k] < F[i][j][k]) begin
                    F[i][j+1][k] <= F[i][j][k];
                    parent[i][j+1][k] <= {i, j, k, 2'b00};  // from (i,j,k), no match
                end
                
                // Match s1[i] and s2[j]
                if (i < len1 && j < len2 && s1[i] == s2[j]) begin
                    // Compute next KMP state
                    reg [3:0] temp_k;
                    temp_k = k;
                    while (temp_k > 4'd0 && virus[temp_k] != s1[i]) begin
                        temp_k = kmp_next[temp_k];
                    end
                    if (virus[temp_k] == s1[i]) begin
                        temp_k = temp_k + 4'd1;
                    end
                    
                    // Check if we reached virus end (invalid transition)
                    if (temp_k < len3) begin
                        if (F[i+1][j+1][temp_k] < F[i][j][k] + 4'd1) begin
                            F[i+1][j+1][temp_k] <= F[i][j][k] + 4'd1;
                            parent[i+1][j+1][temp_k] <= {i, j, k, 2'b01};  // matched
                        end
                    end
                end
                
                k <= k + 4'd1;
                state <= DP_LOOP_K;
            end
            
            FIND_MAX: begin
                // Find maximum value in DP table
                max_val <= 4'd0;
                max_i <= 4'd0;
                max_j <= 4'd0;
                max_k <= 4'd0;
                i <= 4'd0;
                j <= 4'd0;
                k <= 4'd0;
                // Use a sequential search through the table
                if (i < len1 + 4'd1) begin
                    if (j < len2 + 4'd1) begin
                        if (k < len3) begin
                            if (F[i][j][k] > max_val) begin
                                max_val <= F[i][j][k];
                                max_i <= i;
                                max_j <= j;
                                max_k <= k;
                            end
                            k <= k + 4'd1;
                        end else begin
                            k <= 4'd0;
                            j <= j + 4'd1;
                        end
                    end else begin
                        j <= 4'd0;
                        i <= i + 4'd1;
                    end
                end else begin
                    state <= RECONSTRUCT;
                    recon_i <= max_i;
                    recon_j <= max_j;
                    recon_k <= max_k;
                    path_len <= 4'd0;
                    recon_idx <= 4'd0;
                end
            end
            
            RECONSTRUCT: begin
                if (path_len < max_val && recon_idx < max_val) begin
                    // Get parent info
                    reg [15:0] parent_info;
                    parent_info = parent[recon_i][recon_j][recon_k];
                    
                    // Check if this was a match
                    if (parent_info[1:0] == 2'b01) begin
                        // Was a match, store character
                        recon_path[path_len] <= {s1[parent_info[15:12]], 8'd0};
                        path_len <= path_len + 4'd1;
                    end
                    
                    // Move to parent state
                    recon_i <= parent_info[15:12];
                    recon_j <= parent_info[11:8];
                    recon_k <= parent_info[7:4];
                    recon_idx <= recon_idx + 4'd1;
                    
                    // Check if we reached start (0,0,0)
                    if (parent_info[15:12] == 4'd0 && parent_info[11:8] == 4'd0 && parent_info[7:4] == 4'd0) begin
                        state <= OUTPUT_RESULT;
                    end
                end else begin
                    state <= OUTPUT_RESULT;
                end
            end
            
            OUTPUT_RESULT: begin
                // Output result in correct order (reverse)
                if (recon_idx > 4'd0) begin
                    recon_idx <= recon_idx - 4'd1;
                    result[recon_idx - 4'd1] <= recon_path[recon_idx - 4'd1][15:8];
                end else begin
                    result_len <= path_len;
                    state <= FINISH;
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
        
        // Timeout protection
        if (cycle_count >= MAX_CYCLES) begin
            state <= FINISH;
            done <= 1'b1;
            result_len <= 4'd0;
        end
    end
end

endmodule