module marble_vanish(
    input clk,
    input rst_n,
    input start,
    input [2:0] arr_colors [0:15],
    input [3:0] arr_len,
    input [2:0] K_req,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd500;

    // DP table: dp[i][j] = min insertions for interval [i,j]
    reg [7:0] dp [0:15][0:15];
    reg [7:0] temp_dp [0:15][0:15];
    
    // Loop counters
    reg [3:0] i, j, k, len, split;
    reg [2:0] color;
    reg [7:0] min_insertions;
    reg [7:0] current_insertions;
    reg [7:0] left_insertions;
    reg [7:0] right_insertions;
    reg [7:0] extend_insertions;
    reg [7:0] consecutive;
    reg [7:0] required;
    
    // Initialize DP table
    integer idx, jdx;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize DP table
            for (idx = 0; idx < 16; idx = idx + 1) begin
                for (jdx = 0; jdx < 16; jdx = jdx + 1) begin
                    dp[idx][jdx] <= 8'd0;
                    temp_dp[idx][jdx] <= 8'd0;
                end
            end
            
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            len <= 4'd0;
            split <= 4'd0;
            color <= 3'd0;
            min_insertions <= 8'd0;
            current_insertions <= 8'd0;
            left_insertions <= 8'd0;
            right_insertions <= 8'd0;
            extend_insertions <= 8'd0;
            consecutive <= 8'd0;
            required <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Initialize DP table for base cases
                    if (cycle_count == 8'd1) begin
                        for (idx = 0; idx < 16; idx = idx + 1) begin
                            for (jdx = 0; jdx < 16; jdx = jdx + 1) begin
                                if (idx == jdx) begin
                                    dp[idx][jdx] <= 8'd0;
                                end else if (idx < jdx) begin
                                    // Base case: if interval length < K, need K - len insertions
                                    len <= jdx - idx + 4'd1;
                                    if (len < K_req) begin
                                        dp[idx][jdx] <= K_req - len;
                                    end else begin
                                        dp[idx][jdx] <= 8'd255; // Initialize to large value
                                    end
                                end else begin
                                    dp[idx][jdx] <= 8'd0;
                                end
                            end
                        end
                    end
                    
                    // Compute DP table iteratively
                    else if (cycle_count > 8'd1 && cycle_count < 8'd400) begin
                        // Iterate over interval lengths
                        len <= (cycle_count - 8'd2) / 8'd16;
                        i <= (cycle_count - 8'd2) % 8'd16;
                        j <= i + len;
                        
                        if (j < arr_len && len >= K_req) begin
                            // Try all possible splits
                            min_insertions <= 8'd255;
                            for (split = i; split < j; split = split + 1) begin
                                current_insertions <= dp[i][split] + dp[split + 4'd1][j];
                                if (current_insertions < min_insertions) begin
                                    min_insertions <= current_insertions;
                                end
                            end
                            
                            // Try extending existing color groups
                            color <= arr_colors[i];
                            consecutive <= 4'd1;
                            for (k = i + 4'd1; k <= j; k = k + 4'd1) begin
                                if (arr_colors[k] == color) begin
                                    consecutive <= consecutive + 4'd1;
                                end else begin
                                    break;
                                end
                            end
                            
                            if (consecutive >= K_req) begin
                                extend_insertions <= dp[i + consecutive][j];
                                if (extend_insertions < min_insertions) begin
                                    min_insertions <= extend_insertions;
                                end
                            end
                            
                            // Update DP table
                            dp[i][j] <= min_insertions;
                        end
                        
                        // Check if all intervals computed
                        if (cycle_count == 8'd399) begin
                            state <= FINISH;
                        end
                    end
                end
                
                FINISH: begin
                    // Final result is dp[0][N-1]
                    result <= dp[0][arr_len - 4'd1];
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule