module coaster_dp (
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [7:0] Query_T,
    input signed [15:0] a_0, a_1, a_2, a_3, a_4, a_5, a_6, a_7,
    input signed [15:0] b_0, b_1, b_2, b_3, b_4, b_5, b_6, b_7,
    input [7:0] t_0, t_1, t_2, t_3, t_4, t_5, t_6, t_7,
    input [2:0] Query_Index,
    output reg signed [15:0] result,
    output reg done,
    output reg busy
);

    // State machine states
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] PREPARE      = 3'd1;
    localparam [2:0] COMPUTE_FUN  = 3'd2;
    localparam [2:0] DP_UPDATE    = 3'd3;
    localparam [2:0] DP_COMPLETE  = 3'd4;
    localparam [2:0] DONE_STATE   = 3'd5;

    // State and counters
    reg [2:0] state, next_state;
    reg [2:0] coaster_idx;           // 0-7, tracks current coaster
    reg [2:0] ride_cnt;              // 0-7, tracks k (1-8 rides)
    reg [7:0] time_cnt;              // 0-255, tracks current time
    reg [7:0] cycle_cnt;             // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Fun values storage: [coaster][ride_count]
    // ride_cnt=0 is unused (k starts at 1)
    reg signed [15:0] fun_val [0:7][1:8];
    reg signed [15:0] temp_fun;
    
    // DP array for current query (time 0-255)
    reg signed [15:0] dp [0:255];
    reg signed [15:0] new_dp_val;
    reg signed [15:0] dp_t_minus_kt;
    
    // Temporary storage for current coaster parameters
    reg signed [15:0] curr_a, curr_b;
    reg [7:0] curr_t;
    
    // Computation of (k-1)^2 for k=1-8 (0^2 to 7^2)
    // k=1: 0, k=2: 1, k=3: 4, k=4: 9, k=5: 16, k=6: 25, k=7: 36, k=8: 49
    reg [7:0] k_minus_one_sq;
    always @(*) begin
        case (ride_cnt)
            3'd0: k_minus_one_sq = 8'd0;   // k=1 (unused)
            3'd1: k_minus_one_sq = 8'd1;   // k=2: (2-1)^2 = 1
            3'd2: k_minus_one_sq = 8'd4;   // k=3: (3-1)^2 = 4
            3'd3: k_minus_one_sq = 8'd9;   // k=4: (4-1)^2 = 9
            3'd4: k_minus_one_sq = 8'd16;  // k=5: (5-1)^2 = 16
            3'd5: k_minus_one_sq = 8'd25;  // k=6: (6-1)^2 = 25
            3'd6: k_minus_one_sq = 8'd36;  // k=7: (7-1)^2 = 36
            3'd7: k_minus_one_sq = 8'd49;  // k=8: (8-1)^2 = 49
            default: k_minus_one_sq = 8'd0;
        endcase
    end

    // Get current coaster parameters
    always @(*) begin
        case (coaster_idx)
            3'd0: begin curr_a = a_0; curr_b = b_0; curr_t = t_0; end
            3'd1: begin curr_a = a_1; curr_b = b_1; curr_t = t_1; end
            3'd2: begin curr_a = a_2; curr_b = b_2; curr_t = t_2; end
            3'd3: begin curr_a = a_3; curr_b = b_3; curr_t = t_3; end
            3'd4: begin curr_a = a_4; curr_b = b_4; curr_t = t_4; end
            3'd5: begin curr_a = a_5; curr_b = b_5; curr_t = t_5; end
            3'd6: begin curr_a = a_6; curr_b = b_6; curr_t = t_6; end
            3'd7: begin curr_a = a_7; curr_b = b_7; curr_t = t_7; end
            default: begin curr_a = 16'sd0; curr_b = 16'sd0; curr_t = 8'd0; end
        endcase
    end

    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            coaster_idx <= 3'd0;
            ride_cnt <= 3'd0;
            time_cnt <= 8'd0;
            cycle_cnt <= 8'd0;
            result <= 16'sd0;
            done <= 1'b0;
            busy <= 1'b0;
            temp_fun <= 16'sd0;
            new_dp_val <= 16'sd0;
            dp_t_minus_kt <= 16'sd0;
            
            // Initialize dp array
            for (int i = 0; i < 256; i = i + 1) begin
                dp[i] <= 16'sd0;
            end
            
            // Initialize fun_val array
            for (int i = 0; i < 8; i = i + 1) begin
                for (int j = 1; j < 9; j = j + 1) begin
                    fun_val[i][j] <= 16'sd0;
                end
            end
        end else begin
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    cycle_cnt <= 8'd0;
                    if (start) begin
                        busy <= 1'b1;
                        coaster_idx <= 3'd0;
                        ride_cnt <= 3'd0;
                        state <= PREPARE;
                    end
                end
                
                PREPARE: begin
                    // Reset dp array to 0 for new query
                    dp[time_cnt] <= 16'sd0;
                    if (time_cnt < Query_T) begin
                        time_cnt <= time_cnt + 8'd1;
                    end else begin
                        time_cnt <= 8'd0;
                        coaster_idx <= 3'd0;
                        ride_cnt <= 3'd0;
                        state <= COMPUTE_FUN;
                    end
                end
                
                COMPUTE_FUN: begin
                    // Compute fun_val for current coaster and ride count
                    // k = ride_cnt + 1
                    // fun = a - (k-1)^2 * b = a - k_minus_one_sq * b
                    temp_fun <= curr_a - $signed({8'd0, k_minus_one_sq}) * curr_b;
                    
                    // Store if valid (coaster exists, k>=1, and fun>0)
                    if ((coaster_idx < N) && (ride_cnt < 8)) begin
                        if (ride_cnt < 7) begin
                            ride_cnt <= ride_cnt + 3'd1;
                        end else begin
                            ride_cnt <= 3'd0;
                            if (coaster_idx < 7) begin
                                coaster_idx <= coaster_idx + 3'd1;
                            end else begin
                                coaster_idx <= 3'd0;
                                state <= DP_UPDATE;
                            end
                        end
                    end else begin
                        // Skip if coaster doesn't exist
                        if (coaster_idx < 7) begin
                            coaster_idx <= coaster_idx + 3'd1;
                            ride_cnt <= 3'd0;
                        end else begin
                            coaster_idx <= 3'd0;
                            state <= DP_UPDATE;
                        end
                    end
                end
                
                DP_UPDATE: begin
                    // Update dp[time] for each time, coaster, and ride count
                    // Check if valid: time >= k * t_i and fun > 0
                    
                    if (coaster_idx < N) begin
                        if (ride_cnt < 8) begin
                            // Check if this ride count has positive fun for this coaster
                            if (fun_val[coaster_idx][ride_cnt + 1] > 16'sd0) begin
                                if (time_cnt >= ((ride_cnt + 8'd1) * curr_t)) begin
                                    // Compute new value: dp[t] = max(dp[t], dp[t - k*t_i] + k * fun)
                                    dp_t_minus_kt <= dp[time_cnt - ((ride_cnt + 8'd1) * curr_t)];
                                    // k * fun, k = ride_cnt + 1
                                    new_dp_val <= dp[time_cnt - ((ride_cnt + 8'd1) * curr_t)] + 
                                                   $signed({12'd0, ride_cnt + 3'd1}) * fun_val[coaster_idx][ride_cnt + 1];
                                end else begin
                                    new_dp_val <= dp[time_cnt];
                                end
                            end else begin
                                new_dp_val <= dp[time_cnt];
                            end
                        end
                        
                        // Move to next ride count
                        if (ride_cnt < 7) begin
                            ride_cnt <= ride_cnt + 3'd1;
                        end else begin
                            ride_cnt <= 3'd0;
                            if (coaster_idx < 7) begin
                                coaster_idx <= coaster_idx + 3'd1;
                            end else begin
                                // Move to next time
                                if (time_cnt < Query_T) begin
                                    time_cnt <= time_cnt + 8'd1;
                                    coaster_idx <= 3'd0;
                                end else begin
                                    cycle_cnt <= cycle_cnt + 8'd1;
                                    if (cycle_cnt >= MAX_CYCLES) begin
                                        state <= DP_COMPLETE;
                                    end else begin
                                        state <= DP_COMPLETE;
                                    end
                                end
                            end
                        end
                    end
                end
                
                DP_COMPLETE: begin
                    // Final answer is dp[Query_T]
                    result <= dp[Query_T];
                    state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Store computed fun values when computation completes
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 8; i = i + 1) begin
                for (int j = 1; j < 9; j = j + 1) begin
                    fun_val[i][j] <= 16'sd0;
                end
            end
        end else begin
            if (state == COMPUTE_FUN) begin
                // Check if valid and fun > 0
                if ((coaster_idx < N) && (ride_cnt < 8) && (temp_fun > 16'sd0)) begin
                    fun_val[coaster_idx][ride_cnt + 1] <= temp_fun;
                end
            end
        end
    end

    // Update dp array when new value is computed
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 256; i = i + 1) begin
                dp[i] <= 16'sd0;
            end
        end else begin
            if (state == DP_UPDATE) begin
                if (ride_cnt < 8) begin
                    // Use new_dp_val if it's better than current dp[time_cnt]
                    if ((coaster_idx < N) && (fun_val[coaster_idx][ride_cnt + 1] > 16'sd0) && 
                        (time_cnt >= ((ride_cnt + 8'd1) * curr_t))) begin
                        if (new_dp_val > dp[time_cnt]) begin
                            dp[time_cnt] <= new_dp_val;
                        end
                    end
                end
            end
        end
    end

endmodule