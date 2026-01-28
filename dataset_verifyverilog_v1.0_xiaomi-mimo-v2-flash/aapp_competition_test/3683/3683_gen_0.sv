module golf_ranking (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] scores [511:0][49:0],
    input wire [8:0] p,
    input wire [5:0] h,
    output reg [8:0] rank_out [511:0],
    output reg result_ready
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] START_L = 3'd1;
    localparam [2:0] COMPUTE_SUMS = 3'd2;
    localparam [2:0] COMPARE_RANKS = 3'd3;
    localparam [2:0] UPDATE_MIN = 3'd4;
    localparam [2:0] NEXT_L = 3'd5;
    localparam [2:0] DONE = 3'd6;

    reg [2:0] state;
    reg [2:0] next_state;
    
    // Loop counters
    reg [8:0] l_counter;           // ℓ from 1 to 500
    reg [8:0] player_idx;          // Current player index 0..p-1
    reg [8:0] compare_idx;         // For comparing with other players
    reg [8:0] hole_idx;            // Current hole index
    
    // Data storage
    reg [17:0] partial_sum [511:0];     // 18-bit partial sums (max 250k)
    reg [8:0] temp_rank [511:0];        // Temporary rank for current ℓ
    reg [8:0] min_rank [511:0];         // Minimum rank across all ℓ
    reg [17:0] current_total;           // Current player's total score
    reg [17:0] compare_total;           // Comparison player's total score
    
    // Comparison result counter
    reg [8:0] rank_counter;
    
    // Cycle counter for safety (135M cycles)
    reg [31:0] cycle_counter;
    localparam [31:0] MAX_CYCLES = 32'd135000000;
    
    // Intermediate registers for computation
    reg [15:0] score_val;
    reg [17:0] clamped_score;
    reg [17:0] sum_temp;
    
    integer i, j;
    
    // FSM Next State Logic
    always @(*) begin
        next_state = state;  // Default stay in current state
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = START_L;
                end
            end
            
            START_L: begin
                next_state = COMPUTE_SUMS;
            end
            
            COMPUTE_SUMS: begin
                // Done when all holes processed for all players
                if (hole_idx >= h && player_idx >= p) begin
                    next_state = COMPARE_RANKS;
                end
            end
            
            COMPARE_RANKS: begin
                // Done when all players compared for current player
                if (compare_idx >= p) begin
                    next_state = UPDATE_MIN;
                end
            end
            
            UPDATE_MIN: begin
                // Done when all players' min ranks updated
                if (player_idx >= p) begin
                    if (l_counter >= 500) begin
                        next_state = DONE;
                    end else begin
                        next_state = NEXT_L;
                    end
                end
            end
            
            NEXT_L: begin
                next_state = COMPUTE_SUMS;
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            l_counter <= 9'd0;
            player_idx <= 9'd0;
            compare_idx <= 9'd0;
            hole_idx <= 6'd0;
            current_total <= 18'd0;
            compare_total <= 18'd0;
            rank_counter <= 9'd0;
            score_val <= 16'd0;
            clamped_score <= 18'd0;
            sum_temp <= 18'd0;
            result_ready <= 1'b0;
            cycle_counter <= 32'd0;
            
            // Initialize arrays
            for (i = 0; i < 512; i = i + 1) begin
                partial_sum[i] <= 18'd0;
                temp_rank[i] <= 9'd0;
                min_rank[i] <= 9'd0;
                rank_out[i] <= 9'd0;
            end
            
        end else begin
            cycle_counter <= cycle_counter + 32'd1;
            state <= next_state;
            
            case (state)
                IDLE: begin
                    result_ready <= 1'b0;
                    l_counter <= 9'd1;  // Start from ℓ=1
                    player_idx <= 9'd0;
                    compare_idx <= 9'd0;
                    hole_idx <= 6'd0;
                    cycle_counter <= 32'd0;
                end
                
                START_L: begin
                    // Initialize for new ℓ value
                    player_idx <= 9'd0;
                    for (i = 0; i < 512; i = i + 1) begin
                        partial_sum[i] <= 18'd0;
                        temp_rank[i] <= 9'd0;
                    end
                end
                
                COMPUTE_SUMS: begin
                    if (player_idx < p) begin
                        if (hole_idx < h) begin
                            // Read score and compute clamped value
                            score_val <= scores[player_idx][hole_idx];
                            if (scores[player_idx][hole_idx] < l_counter) begin
                                clamped_score <= scores[player_idx][hole_idx];
                            end else begin
                                clamped_score <= l_counter;
                            end
                            // Accumulate sum (add in next cycle)
                            partial_sum[player_idx] <= partial_sum[player_idx] + clamped_score;
                            hole_idx <= hole_idx + 6'd1;
                        end else begin
                            // Done with this player's holes
                            hole_idx <= 6'd0;
                            player_idx <= player_idx + 9'd1;
                        end
                    end
                end
                
                COMPARE_RANKS: begin
                    if (player_idx < p) begin
                        if (compare_idx < p) begin
                            // Compare player_idx with compare_idx
                            if (compare_idx != player_idx) begin
                                if (partial_sum[compare_idx] <= partial_sum[player_idx]) begin
                                    rank_counter <= rank_counter + 9'd1;
                                end
                            end
                            compare_idx <= compare_idx + 9'd1;
                        end else begin
                            // Rank includes player itself (1-based)
                            temp_rank[player_idx] <= rank_counter + 9'd1;
                            rank_counter <= 9'd0;
                            compare_idx <= 9'd0;
                            player_idx <= player_idx + 9'd1;
                        end
                    end
                end
                
                UPDATE_MIN: begin
                    if (player_idx < p) begin
                        // Update minimum rank
                        if (temp_rank[player_idx] < min_rank[player_idx] || l_counter == 9'd1) begin
                            min_rank[player_idx] <= temp_rank[player_idx];
                        end
                        player_idx <= player_idx + 9'd1;
                    end
                end
                
                NEXT_L: begin
                    l_counter <= l_counter + 9'd1;
                    player_idx <= 9'd0;
                    compare_idx <= 9'd0;
                    hole_idx <= 6'd0;
                    // Reset for next iteration
                    for (i = 0; i < 512; i = i + 1) begin
                        partial_sum[i] <= 18'd0;
                        temp_rank[i] <= 9'd0;
                    end
                end
                
                DONE: begin
                    // Copy min_rank to output
                    for (j = 0; j < 512; j = j + 1) begin
                        if (j < p) begin
                            rank_out[j] <= min_rank[j];
                        end
                    end
                    result_ready <= 1'b1;
                    l_counter <= 9'd1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Safety: prevent infinite loops
            if (cycle_counter >= MAX_CYCLES) begin
                state <= DONE;
                result_ready <= 1'b1;
            end
        end
    end
endmodule