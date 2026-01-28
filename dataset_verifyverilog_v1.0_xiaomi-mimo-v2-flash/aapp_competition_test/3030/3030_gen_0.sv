module heap_subset #(
    parameter NODES = 8,
    parameter VAL_WIDTH = 8,
    parameter IDX_WIDTH = 3,
    parameter RESULT_WIDTH = 4
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [VAL_WIDTH-1:0] val [0:NODES-1],
    input wire [IDX_WIDTH-1:0] parent [0:NODES-1],
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] RESET_INIT = 4'd1;
    localparam [3:0] ANC_BUILD  = 4'd2;
    localparam [3:0] SORT_INIT  = 4'd3;
    localparam [3:0] SORT_PASS  = 4'd4;
    localparam [3:0] DP_COMPUTE = 4'd5;
    localparam [3:0] DP_MAX     = 4'd6;
    localparam [3:0] FINISH     = 4'd7;
    
    reg [3:0] state, next_state;
    
    // Internal registers
    reg [2:0] i, j, k, idx;  // Index counters (3-bit)
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Ancestor matrix: anc[i][j] = 1 if i is ancestor of j
    reg anc [0:7][0:7];
    
    // Sorting registers: nodes sorted by value descending
    reg [2:0] sorted_idx [0:7];  // Original node indices
    reg [VAL_WIDTH-1:0] sorted_val [0:7];
    
    // DP table: dp[k] = longest chain ending at sorted node k
    reg [RESULT_WIDTH-1:0] dp [0:7];
    reg [RESULT_WIDTH-1:0] current_max;
    
    // Helper variables for sorting and DP
    reg [VAL_WIDTH-1:0] temp_val;
    reg [2:0] temp_idx;
    reg [RESULT_WIDTH-1:0] max_val;
    
    integer m;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 3'd0;
            j <= 3'd0;
            k <= 3'd0;
            idx <= 3'd0;
            current_max <= 4'd0;
            temp_val <= 8'd0;
            temp_idx <= 3'd0;
            max_val <= 4'd0;
            for (m = 0; m < 8; m = m + 1) begin
                sorted_idx[m] <= 3'd0;
                sorted_val[m] <= 8'd0;
                dp[m] <= 4'd0;
                for (m = 0; m < 8; m = m + 1) begin
                    anc[m][0] <= 1'b0;
                    anc[m][1] <= 1'b0;
                    anc[m][2] <= 1'b0;
                    anc[m][3] <= 1'b0;
                    anc[m][4] <= 1'b0;
                    anc[m][5] <= 1'b0;
                    anc[m][6] <= 1'b0;
                    anc[m][7] <= 1'b0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    i <= 3'd0;
                    j <= 3'd0;
                    k <= 3'd0;
                    idx <= 3'd0;
                    current_max <= 4'd0;
                    if (start) begin
                        state <= RESET_INIT;
                    end
                end
                
                RESET_INIT: begin
                    // Clear all matrices and tables
                    for (m = 0; m < 8; m = m + 1) begin
                        sorted_idx[m] <= 3'd0;
                        sorted_val[m] <= 8'd0;
                        dp[m] <= 4'd0;
                    end
                    for (m = 0; m < 8; m = m + 1) begin
                        anc[m][0] <= 1'b0;
                        anc[m][1] <= 1'b0;
                        anc[m][2] <= 1'b0;
                        anc[m][3] <= 1'b0;
                        anc[m][4] <= 1'b0;
                        anc[m][5] <= 1'b0;
                        anc[m][6] <= 1'b0;
                        anc[m][7] <= 1'b0;
                    end
                    state <= ANC_BUILD;
                    i <= 3'd0;
                    j <= 3'd0;
                end
                
                ANC_BUILD: begin
                    // Build ancestor matrix
                    // anc[i][j] = 1 if i is ancestor of j
                    // Check if parent[j] == i or parent[j] is ancestor of i
                    if (i != j) begin
                        // Check direct parent
                        if (parent[j] == i) begin
                            anc[i][j] <= 1'b1;
                        end else if (parent[j] != 3'd0) begin
                            // Check if parent[j] is ancestor of i
                            anc[i][j] <= anc[parent[j]][i];
                        end else begin
                            anc[i][j] <= anc[0][i];
                        end
                    end else begin
                        // Every node is its own ancestor
                        anc[i][j] <= 1'b1;
                    end
                    
                    // Update indices
                    if (j < 3'd7) begin
                        j <= j + 3'd1;
                    end else begin
                        j <= 3'd0;
                        if (i < 3'd7) begin
                            i <= i + 3'd1;
                        end else begin
                            i <= 3'd0;
                            state <= SORT_INIT;
                        end
                    end
                    cycle_count <= cycle_count + 8'd1;
                end
                
                SORT_INIT: begin
                    // Initialize sorted arrays
                    for (m = 0; m < 8; m = m + 1) begin
                        sorted_idx[m] <= m[2:0];
                        sorted_val[m] <= val[m];
                    end
                    i <= 3'd0;
                    state <= SORT_PASS;
                end
                
                SORT_PASS: begin
                    // Bitonic sort network for 8 elements
                    // Pass 1: Compare and swap (0-1), (2-3), (4-5), (6-7)
                    if (i == 3'd0) begin
                        // Sort ascending (actually descending by value)
                        if (sorted_val[0] < sorted_val[1]) begin
                            temp_val <= sorted_val[0];
                            temp_idx <= sorted_idx[0];
                            sorted_val[0] <= sorted_val[1];
                            sorted_idx[0] <= sorted_idx[1];
                            sorted_val[1] <= temp_val;
                            sorted_idx[1] <= temp_idx;
                        end
                        if (sorted_val[2] < sorted_val[3]) begin
                            temp_val <= sorted_val[2];
                            temp_idx <= sorted_idx[2];
                            sorted_val[2] <= sorted_val[3];
                            sorted_idx[2] <= sorted_idx[3];
                            sorted_val[3] <= temp_val;
                            sorted_idx[3] <= temp_idx;
                        end
                        if (sorted_val[4] < sorted_val[5]) begin
                            temp_val <= sorted_val[4];
                            temp_idx <= sorted_idx[4];
                            sorted_val[4] <= sorted_val[5];
                            sorted_idx[4] <= sorted_idx[5];
                            sorted_val[5] <= temp_val;
                            sorted_idx[5] <= temp_idx;
                        end
                        if (sorted_val[6] < sorted_val[7]) begin
                            temp_val <= sorted_val[6];
                            temp_idx <= sorted_idx[6];
                            sorted_val[6] <= sorted_val[7];
                            sorted_idx[6] <= sorted_idx[7];
                            sorted_val[7] <= temp_val;
                            sorted_idx[7] <= temp_idx;
                        end
                        i <= 3'd1;
                    end
                    // Pass 2: Compare and swap (0-2), (1-3), (4-6), (5-7)
                    else if (i == 3'd1) begin
                        if (sorted_val[0] < sorted_val[2]) begin
                            temp_val <= sorted_val[0];
                            temp_idx <= sorted_idx[0];
                            sorted_val[0] <= sorted_val[2];
                            sorted_idx[0] <= sorted_idx[2];
                            sorted_val[2] <= temp_val;
                            sorted_idx[2] <= temp_idx;
                        end
                        if (sorted_val[1] < sorted_val[3]) begin
                            temp_val <= sorted_val[1];
                            temp_idx <= sorted_idx[1];
                            sorted_val[1] <= sorted_val[3];
                            sorted_idx[1] <= sorted_idx[3];
                            sorted_val[3] <= temp_val;
                            sorted_idx[3] <= temp_idx;
                        end
                        if (sorted_val[4] < sorted_val[6]) begin
                            temp_val <= sorted_val[4];
                            temp_idx <= sorted_idx[4];
                            sorted_val[4] <= sorted_val[6];
                            sorted_idx[4] <= sorted_idx[6];
                            sorted_val[6] <= temp_val;
                            sorted_idx[6] <= temp_idx;
                        end
                        if (sorted_val[5] < sorted_val[7]) begin
                            temp_val <= sorted_val[5];
                            temp_idx <= sorted_idx[5];
                            sorted_val[5] <= sorted_val[7];
                            sorted_idx[5] <= sorted_idx[7];
                            sorted_val[7] <= temp_val;
                            sorted_idx[7] <= temp_idx;
                        end
                        i <= 3'd2;
                    end
                    // Pass 3: Compare and swap (0-4), (1-5), (2-6), (3-7)
                    else if (i == 3'd2) begin
                        if (sorted_val[0] < sorted_val[4]) begin
                            temp_val <= sorted_val[0];
                            temp_idx <= sorted_idx[0];
                            sorted_val[0] <= sorted_val[4];
                            sorted_idx[0] <= sorted_idx[4];
                            sorted_val[4] <= temp_val;
                            sorted_idx[4] <= temp_idx;
                        end
                        if (sorted_val[1] < sorted_val[5]) begin
                            temp_val <= sorted_val[1];
                            temp_idx <= sorted_idx[1];
                            sorted_val[1] <= sorted_val[5];
                            sorted_idx[1] <= sorted_idx[5];
                            sorted_val[5] <= temp_val;
                            sorted_idx[5] <= temp_idx;
                        end
                        if (sorted_val[2] < sorted_val[6]) begin
                            temp_val <= sorted_val[2];
                            temp_idx <= sorted_idx[2];
                            sorted_val[2] <= sorted_val[6];
                            sorted_idx[2] <= sorted_idx[6];
                            sorted_val[6] <= temp_val;
                            sorted_idx[6] <= temp_idx;
                        end
                        if (sorted_val[3] < sorted_val[7]) begin
                            temp_val <= sorted_val[3];
                            temp_idx <= sorted_idx[3];
                            sorted_val[3] <= sorted_val[7];
                            sorted_idx[3] <= sorted_idx[7];
                            sorted_val[7] <= temp_val;
                            sorted_idx[7] <= temp_idx;
                        end
                        i <= 3'd3;
                    end
                    // Pass 4: Compare and swap (1-2), (5-6)
                    else if (i == 3'd3) begin
                        if (sorted_val[1] < sorted_val[2]) begin
                            temp_val <= sorted_val[1];
                            temp_idx <= sorted_idx[1];
                            sorted_val[1] <= sorted_val[2];
                            sorted_idx[1] <= sorted_idx[2];
                            sorted_val[2] <= temp_val;
                            sorted_idx[2] <= temp_idx;
                        end
                        if (sorted_val[5] < sorted_val[6]) begin
                            temp_val <= sorted_val[5];
                            temp_idx <= sorted_idx[5];
                            sorted_val[5] <= sorted_val[6];
                            sorted_idx[5] <= sorted_idx[6];
                            sorted_val[6] <= temp_val;
                            sorted_idx[6] <= temp_idx;
                        end
                        i <= 3'd4;
                    end
                    // Pass 5: Compare and swap (0-1), (2-3), (4-5), (6-7)
                    else if (i == 3'd4) begin
                        if (sorted_val[0] < sorted_val[1]) begin
                            temp_val <= sorted_val[0];
                            temp_idx <= sorted_idx[0];
                            sorted_val[0] <= sorted_val[1];
                            sorted_idx[0] <= sorted_idx[1];
                            sorted_val[1] <= temp_val;
                            sorted_idx[1] <= temp_idx;
                        end
                        if (sorted_val[2] < sorted_val[3]) begin
                            temp_val <= sorted_val[2];
                            temp_idx <= sorted_idx[2];
                            sorted_val[2] <= sorted_val[3];
                            sorted_idx[2] <= sorted_idx[3];
                            sorted_val[3] <= temp_val;
                            sorted_idx[3] <= temp_idx;
                        end
                        if (sorted_val[4] < sorted_val[5]) begin
                            temp_val <= sorted_val[4];
                            temp_idx <= sorted_idx[4];
                            sorted_val[4] <= sorted_val[5];
                            sorted_idx[4] <= sorted_idx[5];
                            sorted_val[5] <= temp_val;
                            sorted_idx[5] <= temp_idx;
                        end
                        if (sorted_val[6] < sorted_val[7]) begin
                            temp_val <= sorted_val[6];
                            temp_idx <= sorted_idx[6];
                            sorted_val[6] <= sorted_val[7];
                            sorted_idx[6] <= sorted_idx[7];
                            sorted_val[7] <= temp_val;
                            sorted_idx[7] <= temp_idx;
                        end
                        i <= 3'd5;
                    end
                    // Pass 6: Compare and swap (0-2), (1-3), (4-6), (5-7)
                    else if (i == 3'd5) begin
                        if (sorted_val[0] < sorted_val[2]) begin
                            temp_val <= sorted_val[0];
                            temp_idx <= sorted_idx[0];
                            sorted_val[0] <= sorted_val[2];
                            sorted_idx[0] <= sorted_idx[2];
                            sorted_val[2] <= temp_val;
                            sorted_idx[2] <= temp_idx;
                        end
                        if (sorted_val[1] < sorted_val[3]) begin
                            temp_val <= sorted_val[1];
                            temp_idx <= sorted_idx[1];
                            sorted_val[1] <= sorted_val[3];
                            sorted_idx[1] <= sorted_idx[3];
                            sorted_val[3] <= temp_val;
                            sorted_idx[3] <= temp_idx;
                        end
                        if (sorted_val[4] < sorted_val[6]) begin
                            temp_val <= sorted_val[4];
                            temp_idx <= sorted_idx[4];
                            sorted_val[4] <= sorted_val[6];
                            sorted_idx[4] <= sorted_idx[6];
                            sorted_val[6] <= temp_val;
                            sorted_idx[6] <= temp_idx;
                        end
                        if (sorted_val[5] < sorted_val[7]) begin
                            temp_val <= sorted_val[5];
                            temp_idx <= sorted_idx[5];
                            sorted_val[5] <= sorted_val[7];
                            sorted_idx[5] <= sorted_idx[7];
                            sorted_val[7] <= temp_val;
                            sorted_idx[7] <= temp_idx;
                        end
                        i <= 3'd6;
                    end
                    // Pass 7: Compare and swap (0-4), (1-5), (2-6), (3-7)
                    else if (i == 3'd6) begin
                        if (sorted_val[0] < sorted_val[4]) begin
                            temp_val <= sorted_val[0];
                            temp_idx <= sorted_idx[0];
                            sorted_val[0] <= sorted_val[4];
                            sorted_idx[0] <= sorted_idx[4];
                            sorted_val[4] <= temp_val;
                            sorted_idx[4] <= temp_idx;
                        end
                        if (sorted_val[1] < sorted_val[5]) begin
                            temp_val <= sorted_val[1];
                            temp_idx <= sorted_idx[1];
                            sorted_val[1] <= sorted_val[5];
                            sorted_idx[1] <= sorted_idx[5];
                            sorted_val[5] <= temp_val;
                            sorted_idx[5] <= temp_idx;
                        end
                        if (sorted_val[2] < sorted_val[6]) begin
                            temp_val <= sorted_val[2];
                            temp_idx <= sorted_idx[2];
                            sorted_val[2] <= sorted_val[6];
                            sorted_idx[2] <= sorted_idx[6];
                            sorted_val[6] <= temp_val;
                            sorted_idx[6] <= temp_idx;
                        end
                        if (sorted_val[3] < sorted_val[7]) begin
                            temp_val <= sorted_val[3];
                            temp_idx <= sorted_idx[3];
                            sorted_val[3] <= sorted_val[7];
                            sorted_idx[3] <= sorted_idx[7];
                            sorted_val[7] <= temp_val;
                            sorted_idx[7] <= temp_idx;
                        end
                        i <= 3'd7;
                    end
                    // Pass 8: Compare and swap (1-2), (5-6)
                    else if (i == 3'd7) begin
                        if (sorted_val[1] < sorted_val[2]) begin
                            temp_val <= sorted_val[1];
                            temp_idx <= sorted_idx[1];
                            sorted_val[1] <= sorted_val[2];
                            sorted_idx[1] <= sorted_idx[2];
                            sorted_val[2] <= temp_val;
                            sorted_idx[2] <= temp_idx;
                        end
                        if (sorted_val[5] < sorted_val[6]) begin
                            temp_val <= sorted_val[5];
                            temp_idx <= sorted_idx[5];
                            sorted_val[5] <= sorted_val[6];
                            sorted_idx[5] <= sorted_idx[6];
                            sorted_val[6] <= temp_val;
                            sorted_idx[6] <= temp_idx;
                        end
                        i <= 3'd0;
                        state <= DP_COMPUTE;
                    end
                    cycle_count <= cycle_count + 8'd1;
                end
                
                DP_COMPUTE: begin
                    // For each sorted node k, compute dp[k]
                    // dp[k] = 1 + max(dp[j] where anc[j][k]=1 and val[j] > val[k])
                    // Initialize dp[k] to 1 (at least the node itself)
                    if (i == 3'd0) begin
                        dp[k] <= 4'd1;
                        j <= 3'd0;
                        i <= 3'd1;
                    end
                    // Check each ancestor j
                    else if (i == 3'd1) begin
                        // Check if anc[j][k] and val[j] > sorted_val[k]
                        if (anc[sorted_idx[j]][sorted_idx[k]]) begin
                            // Check value condition (ancestor must have larger value)
                            if (val[sorted_idx[j]] > sorted_val[k]) begin
                                // Update dp[k] if better
                                if (dp[j] + 4'd1 > dp[k]) begin
                                    dp[k] <= dp[j] + 4'd1;
                                end
                            end
                        end
                        
                        // Move to next j
                        if (j < 3'd7) begin
                            j <= j + 3'd1;
                        end else begin
                            // Done with this k, move to next k
                            if (k < 3'd7) begin
                                k <= k + 3'd1;
                                i <= 3'd0;
                            end else begin
                                k <= 3'd0;
                                state <= DP_MAX;
                            end
                        end
                    end
                    cycle_count <= cycle_count + 8'd1;
                end
                
                DP_MAX: begin
                    // Find maximum in dp array
                    if (i == 3'd0) begin
                        current_max <= 4'd0;
                        i <= 3'd1;
                    end else if (i == 3'd1) begin
                        if (dp[j] > current_max) begin
                            current_max <= dp[j];
                        end
                        if (j < 3'd7) begin
                            j <= j + 3'd1;
                        end else begin
                            result <= current_max;
                            state <= FINISH;
                        end
                    end
                    cycle_count <= cycle_count + 8'd1;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
                state <= FINISH;
                result <= 4'd0;
            end
        end
    end
endmodule