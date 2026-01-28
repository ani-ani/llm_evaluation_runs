module MarbleVanishingDP (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] arr_len,
    input wire [2:0] K_req,
    input wire [3:0] arr_colors [0:15],
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] INIT       = 4'd1;
    localparam [3:0] DP_BASE    = 4'd2;
    localparam [3:0] DP_MAIN    = 4'd3;
    localparam [3:0] DP_SPLITS  = 4'd4;
    localparam [3:0] DP_COLORS  = 4'd5;
    localparam [3:0] UPDATE_DP  = 4'd6;
    localparam [3:0] FINISH     = 4'd7;

    reg [3:0] state, next_state;
    
    // DP table: 16x16 entries, each 8-bit
    reg [7:0] dp [0:15][0:15];
    
    // Counter and loop variables
    reg [3:0] len, i, j, k, m, p, q;
    reg [7:0] min_val;
    reg [7:0] temp_val;
    reg [7:0] calc_val;
    reg [3:0] split_idx;
    reg [2:0] color_idx;
    reg [3:0] color_start;
    reg [3:0] color_end;
    reg [3:0] consecutive;
    reg [3:0] current_color;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            len <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            m <= 4'd0;
            p <= 4'd0;
            q <= 4'd0;
            min_val <= 8'd0;
            temp_val <= 8'd0;
            calc_val <= 8'd0;
            split_idx <= 4'd0;
            color_idx <= 3'd0;
            color_start <= 4'd0;
            color_end <= 4'd0;
            consecutive <= 4'd0;
            current_color <= 4'd0;
            // Initialize DP table
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    dp[i][j] <= 8'd0;
                end
            end
        end else begin
            cycle_count <= cycle_count + 8'd1;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 8'd0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    // Initialize DP table for base cases
                    if (i < arr_len) begin
                        // Initialize dp[i][i] = K_req - 1 (need K-1 more to make K)
                        if (K_req > 4'd1) begin
                            dp[i][i] <= K_req - 4'd1;
                        end else begin
                            dp[i][i] <= 8'd0;
                        end
                        i <= i + 4'd1;
                    end else begin
                        i <= 4'd0;
                        len <= 4'd2; // Start with length 2
                        state <= DP_BASE;
                    end
                end
                
                DP_BASE: begin
                    // Process intervals of length 2 to K_req-1
                    if (len <= K_req && len <= arr_len) begin
                        if (i <= arr_len - len) begin
                            j <= i + len - 4'd1;
                            // Calculate base insertion needed for interval [i, j]
                            if (len < K_req) begin
                                dp[i][i+len-1] <= K_req - len;
                            end else begin
                                // Check if all same color
                                if (arr_colors[i] == arr_colors[i+len-1]) begin
                                    // Count consecutive same color
                                    consecutive <= 4'd1;
                                    current_color <= arr_colors[i];
                                    k <= 4'd1;
                                    calc_val <= 8'd0;
                                    state <= DP_COLORS;
                                end else begin
                                    // Different colors at ends, still need K insertions
                                    dp[i][i+len-1] <= K_req;
                                end
                            end
                            i <= i + 4'd1;
                        end else begin
                            i <= 4'd0;
                            len <= len + 4'd1;
                        end
                    end else begin
                        len <= 4'd2;
                        state <= DP_MAIN;
                    end
                end
                
                DP_COLORS: begin
                    // Count consecutive same color in interval [i, j]
                    if (k < len) begin
                        if (arr_colors[i+k] == current_color) begin
                            consecutive <= consecutive + 4'd1;
                        end
                        k <= k + 4'd1;
                    end else begin
                        // If consecutive >= K_req, we can vanish this group
                        // cost = 0, otherwise cost = K_req - consecutive
                        if (consecutive >= K_req) begin
                            dp[i][i+len-1] <= 8'd0;
                        end else begin
                            dp[i][i+len-1] <= K_req - consecutive;
                        end
                        state <= DP_BASE;
                    end
                end
                
                DP_MAIN: begin
                    // Main DP: process intervals of increasing length
                    if (len <= arr_len) begin
                        if (i <= arr_len - len) begin
                            j <= i + len - 4'd1;
                            min_val <= 8'd255; // Initialize min to max
                            split_idx <= i + 4'd1;
                            state <= DP_SPLITS;
                        end else begin
                            if (len < arr_len) begin
                                i <= 4'd0;
                                len <= len + 4'd1;
                            end else begin
                                state <= FINISH;
                            end
                        end
                    end else begin
                        state <= FINISH;
                    end
                end
                
                DP_SPLITS: begin
                    // Try all possible split points
                    if (split_idx <= j) begin
                        // Calculate cost for splitting at split_idx
                        temp_val <= dp[i][split_idx-1] + dp[split_idx][j];
                        split_idx <= split_idx + 4'd1;
                        state <= UPDATE_DP;
                    end else begin
                        // Also consider extending existing color groups
                        // Check if we can combine with same color at ends
                        if (arr_colors[i] == arr_colors[j]) begin
                            // Count consecutive same color from start
                            color_start <= 4'd1;
                            current_color <= arr_colors[i];
                            color_idx <= 3'd1;
                            state <= DP_COLORS;
                        end else begin
                            // Store min value
                            dp[i][j] <= min_val;
                            i <= i + 4'd1;
                            state <= DP_MAIN;
                        end
                    end
                end
                
                UPDATE_DP: begin
                    // Update min with split cost
                    if (temp_val < min_val) begin
                        min_val <= temp_val;
                    end
                    state <= DP_SPLITS;
                end
                
                DP_COLORS: begin
                    // Extended logic for color combination
                    if (color_idx < K_req && color_idx < len) begin
                        if (arr_colors[i+color_idx] == current_color) begin
                            color_start <= color_start + 4'd1;
                        end
                        color_idx <= color_idx + 3'd1;
                    end else if (color_idx == K_req) begin
                        // Check end consecutive
                        color_end <= 4'd1;
                        color_idx <= 3'd1;
                    end else begin
                        // Calculate combined cost
                        if (color_start >= K_req) begin
                            // Can vanish start group, then dp from i+K_req to j
                            if (i + K_req <= j) begin
                                calc_val <= dp[i + K_req][j];
                            end else begin
                                calc_val <= 8'd0;
                            end
                        end else begin
                            // Need to insert to make start group of size K_req
                            calc_val <= (K_req - color_start) + dp[i + color_start][j];
                        end
                        if (calc_val < min_val) begin
                            min_val <= calc_val;
                        end
                        dp[i][j] <= min_val;
                        i <= i + 4'd1;
                        state <= DP_MAIN;
                    end
                end
                
                FINISH: begin
                    if (arr_len > 4'd0) begin
                        result <= dp[0][arr_len-1];
                    end else begin
                        result <= 8'd0;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Timeout protection
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
                state <= FINISH;
            end
        end
    end
endmodule