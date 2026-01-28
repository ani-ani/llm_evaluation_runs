module grasshopper (
    input clk,
    input rst_n,
    input start,
    // Grid values (8-bit each)
    input [7:0] grid_0_0, grid_0_1, grid_0_2, grid_0_3,
                 grid_1_0, grid_1_1, grid_1_2, grid_1_3,
                 grid_2_0, grid_2_1, grid_2_2, grid_2_3,
                 grid_3_0, grid_3_1, grid_3_2, grid_3_3,
    input [1:0] start_row, start_col,  // 0-indexed
    output reg [4:0] max_length,
    output reg done
);

// State definitions
localparam [3:0] S_IDLE = 4'd0;
localparam [3:0] S_LOAD = 4'd1;
localparam [3:0] S_SORT_INIT = 4'd2;
localparam [3:0] S_SORT_LOOP = 4'd3;
localparam [3:0] S_SORT_COMPARE = 4'd4;
localparam [3:0] S_SORT_SWAP = 4'd5;
localparam [3:0] S_SORT_NEXT = 4'd6;
localparam [3:0] S_DP_INIT = 4'd7;
localparam [3:0] S_DP_OUTER = 4'd8;
localparam [3:0] S_DP_INNER = 4'd9;
localparam [3:0] S_DP_UPDATE = 4'd10;
localparam [3:0] S_DP_NEXT_J = 4'd11;
localparam [3:0] S_DP_NEXT_K = 4'd12;
localparam [3:0] S_RESULT = 4'd13;
localparam [3:0] S_DONE = 4'd14;

// Registers
reg [3:0] state;
reg [3:0] pass, i, k, j;  // counters
reg [7:0] petal [0:15];   // petal values
reg [3:0] idx [0:15];     // permutation indices
reg [4:0] dp [0:15];      // DP values
reg [4:0] max_length_reg;

// Temporary registers for swap
reg [7:0] temp_petal;
reg [3:0] temp_idx;

// Coordinates and move calculation
reg [1:0] r_i, c_i, r_j, c_j;
reg [1:0] diff_r, diff_c;
reg move_allowed;

// Combinational logic for move check
always @(*) begin
    // Coordinates from idx (i and j are current indices in petal array)
    r_i = idx[i][3:2];
    c_i = idx[i][1:0];
    r_j = idx[j][3:2];
    c_j = idx[j][1:0];
    
    // Absolute differences
    if (r_i > r_j) diff_r = r_i - r_j; else diff_r = r_j - r_i;
    if (c_i > c_j) diff_c = c_i - c_j; else diff_c = c_j - c_i;
    
    // Movement rule: (|r_i - r_j| == 1 && |c_i - c_j| >= 2) || (|c_i - c_j| == 1 && |r_i - r_j| >= 2)
    move_allowed = ((diff_r == 1 && diff_c >= 2) || (diff_c == 1 && diff_r >= 2));
end

// Main state machine and sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        done <= 1'b0;
        max_length <= 5'd0;
        pass <= 4'd0;
        i <= 4'd0;
        k <= 4'd0;
        j <= 4'd0;
    end else begin
        case (state)
            S_IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= S_LOAD;
                end
            end
            
            S_LOAD: begin
                // Load grid into petal array
                petal[0] <= grid_0_0; petal[1] <= grid_0_1; petal[2] <= grid_0_2; petal[3] <= grid_0_3;
                petal[4] <= grid_1_0; petal[5] <= grid_1_1; petal[6] <= grid_1_2; petal[7] <= grid_1_3;
                petal[8] <= grid_2_0; petal[9] <= grid_2_1; petal[10] <= grid_2_2; petal[11] <= grid_2_3;
                petal[12] <= grid_3_0; petal[13] <= grid_3_1; petal[14] <= grid_3_2; petal[15] <= grid_3_3;
                // Initialize indices - using individual assignment
                idx[0] <= 4'd0; idx[1] <= 4'd1; idx[2] <= 4'd2; idx[3] <= 4'd3;
                idx[4] <= 4'd4; idx[5] <= 4'd5; idx[6] <= 4'd6; idx[7] <= 4'd7;
                idx[8] <= 4'd8; idx[9] <= 4'd9; idx[10] <= 4'd10; idx[11] <= 4'd11;
                idx[12] <= 4'd12; idx[13] <= 4'd13; idx[14] <= 4'd14; idx[15] <= 4'd15;
                state <= S_SORT_INIT;
            end
            
            S_SORT_INIT: begin
                pass <= 4'd0;
                i <= 4'd0;
                state <= S_SORT_LOOP;
            end
            
            S_SORT_LOOP: begin
                if (i < 4'd14) begin
                    state <= S_SORT_COMPARE;
                end else begin
                    pass <= pass + 4'd1;
                    i <= 4'd0;
                    if (pass >= 4'd15) begin
                        state <= S_DP_INIT;
                    end else begin
                        state <= S_SORT_LOOP;
                    end
                end
            end
            
            S_SORT_COMPARE: begin
                // Compare petal[i] and petal[i+1] (descending order)
                if (petal[i] < petal[i+1]) begin
                    state <= S_SORT_SWAP;
                end else begin
                    state <= S_SORT_NEXT;
                end
            end
            
            S_SORT_SWAP: begin
                // Swap petal[i] and petal[i+1]
                temp_petal <= petal[i];
                petal[i] <= petal[i+1];
                petal[i+1] <= temp_petal;
                // Swap idx[i] and idx[i+1]
                temp_idx <= idx[i];
                idx[i] <= idx[i+1];
                idx[i+1] <= temp_idx;
                state <= S_SORT_NEXT;
            end
            
            S_SORT_NEXT: begin
                i <= i + 4'd1;
                state <= S_SORT_LOOP;
            end
            
            S_DP_INIT: begin
                // Initialize dp to 1 for all cells
                dp[0] <= 5'd1; dp[1] <= 5'd1; dp[2] <= 5'd1; dp[3] <= 5'd1;
                dp[4] <= 5'd1; dp[5] <= 5'd1; dp[6] <= 5'd1; dp[7] <= 5'd1;
                dp[8] <= 5'd1; dp[9] <= 5'd1; dp[10] <= 5'd1; dp[11] <= 5'd1;
                dp[12] <= 5'd1; dp[13] <= 5'd1; dp[14] <= 5'd1; dp[15] <= 5'd1;
                k <= 4'd0;
                state <= S_DP_OUTER;
            end
            
            S_DP_OUTER: begin
                if (k < 4'd16) begin
                    j <= 4'd0;
                    state <= S_DP_INNER;
                end else begin
                    state <= S_RESULT;
                end
            end
            
            S_DP_INNER: begin
                if (j < 4'd16) begin
                    state <= S_DP_UPDATE;
                end else begin
                    state <= S_DP_NEXT_K;
                end
            end
            
            S_DP_UPDATE: begin
                // Check if move allowed and petal[j] > petal[k]
                if (move_allowed && (petal[j] > petal[idx[k]])) begin
                    // dp[k] = max(dp[k], dp[j] + 1)
                    if (dp[idx[k]] < dp[j] + 5'd1) begin
                        dp[idx[k]] <= dp[j] + 5'd1;
                    end
                end
                state <= S_DP_NEXT_J;
            end
            
            S_DP_NEXT_J: begin
                j <= j + 4'd1;
                state <= S_DP_INNER;
            end
            
            S_DP_NEXT_K: begin
                k <= k + 4'd1;
                state <= S_DP_OUTER;
            end
            
            S_RESULT: begin
                // Compute start index = start_row * 4 + start_col
                max_length_reg <= dp[{start_row, start_col}];
                state <= S_DONE;
            end
            
            S_DONE: begin
                max_length <= max_length_reg;
                done <= 1'b1;
                if (!start) begin
                    state <= S_IDLE;
                end
            end
            
            default: state <= S_IDLE;
        endcase
    end
end

endmodule