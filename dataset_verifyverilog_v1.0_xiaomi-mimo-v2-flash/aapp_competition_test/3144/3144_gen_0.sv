module card_game_betting(
    input clk,
    input rst_n,
    input start,
    input [9:0] d_init,
    input [9:0] g_init,
    input [5:0] n,
    input [5:0] k,
    output reg [10:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] INIT_DP      = 3'd1;
    localparam [2:0] COMPUTE_DONALD = 3'd2;
    localparam [2:0] COMPUTE_GLADSTONE = 3'd3;
    localparam [2:0] NEXT_STATE   = 3'd4;
    localparam [2:0] FINISH       = 3'd5;

    // State variables
    reg [2:0] state, next_state;
    reg [5:0] round_num;       // 0 to 50
    reg [5:0] dist_used;       // 0 to 50
    reg [9:0] d_coins;         // 0 to 1000
    reg [9:0] g_coins;         // 0 to 1000
    reg [9:0] bet_amount;      // 0 to 1000
    reg [9:0] temp_max;        // For max tracking
    reg [9:0] temp_min;        // For min tracking
    reg [10:0] best_value;     // Best value for current state
    reg [10:0] candidate_value; // Candidate value from DP lookup
    reg [10:0] dp_prev [0:50][0:1000]; // DP for previous round: [dist][g_coins]
    reg [10:0] dp_curr [0:50][0:1000]; // DP for current round: [dist][g_coins]
    reg [7:0] cycle_count;     // For timeout
    localparam [7:0] MAX_CYCLES = 8'd100; // Max cycles per state

    // Helper indices
    reg [5:0] dist_idx;
    reg [9:0] g_idx;
    reg [9:0] d_idx;

    // Combinational logic for DP lookup
    wire [10:0] lookup_prev;
    wire [10:0] lookup_candidate;
    assign lookup_prev = (state == COMPUTE_GLADSTONE) ? 
                         ((dist_idx <= dist_used) && (d_idx >= bet_amount) && (d_idx > 0)) ? 
                         dp_prev[dist_idx][d_idx - bet_amount] : 11'h7FF : 11'h7FF;
    assign lookup_candidate = (state == COMPUTE_GLADSTONE) ? 
                              ((dist_idx <= dist_used) && (d_coins >= bet_amount)) ? 
                              dp_prev[dist_idx][d_coins - bet_amount] : 11'h7FF : 11'h7FF;

    integer i, j;

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 11'd0;
            done <= 1'b0;
            round_num <= 6'd0;
            dist_used <= 6'd0;
            d_coins <= 10'd0;
            g_coins <= 10'd0;
            bet_amount <= 10'd1;
            temp_max <= 10'd0;
            temp_min <= 10'd0;
            best_value <= 11'd0;
            candidate_value <= 11'd0;
            cycle_count <= 8'd0;
            dist_idx <= 6'd0;
            g_idx <= 10'd0;
            d_idx <= 10'd0;
            for (i = 0; i < 51; i = i + 1) begin
                for (j = 0; j < 1001; j = j + 1) begin
                    dp_prev[i][j] <= 11'd0;
                    dp_curr[i][j] <= 11'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT_DP;
                        round_num <= 6'd0;
                        dist_used <= 6'd0;
                        d_coins <= d_init;
                        g_coins <= g_init;
                        bet_amount <= 10'd1;
                        best_value <= 11'd0;
                        candidate_value <= 11'd0;
                        cycle_count <= 8'd0;
                        dist_idx <= 6'd0;
                        g_idx <= 10'd0;
                        d_idx <= 10'd0;
                        // Initialize result
                        result <= (d_init > 10'd1000) ? 11'd1000 : {1'd0, d_init};
                    end
                end

                INIT_DP: begin
                    // Initialize dp_prev for round 0
                    if (cycle_count < 100) begin
                        for (i = 0; i < 51; i = i + 1) begin
                            dp_prev[i][cycle_count] <= {1'd0, cycle_count};
                        end
                        cycle_count <= cycle_count + 8'd1;
                    end else begin
                        cycle_count <= 8'd0;
                        round_num <= 6'd1;
                        dist_used <= 6'd0;
                        state <= COMPUTE_DONALD;
                        // Reset dp_curr
                        for (i = 0; i < 51; i = i + 1) begin
                            for (j = 0; j < 1001; j = j + 1) begin
                                dp_curr[i][j] <= 11'd0;
                            end
                        end
                    end
                end

                COMPUTE_DONALD: begin
                    // Compute dp_curr for distracted round
                    // For each dist_used, for each g_coins, compute best outcome
                    if (dist_used <= k) begin
                        if (g_idx <= g_coins) begin
                            // Compute for current dist_used and g_idx
                            // Initialize best_value
                            best_value <= 11'd0;
                            bet_amount <= 10'd1;
                            state <= COMPUTE_GLADSTONE;
                        end else begin
                            // Next g_coins
                            g_idx <= 10'd0;
                            dist_idx <= dist_idx + 6'd1;
                            if (dist_idx > k) begin
                                // Next dist_used
                                dist_idx <= 6'd0;
                                dist_used <= dist_used + 6'd1;
                                if (dist_used > k) begin
                                    // All dist_used computed
                                    state <= NEXT_STATE;
                                end
                            end
                        end
                    end else begin
                        dist_used <= 6'd0;
                        state <= NEXT_STATE;
                    end
                end

                COMPUTE_GLADSTONE: begin
                    // For distracted round, Donald wins: maximize outcome
                    // For normal round, Gladstone wins: minimize outcome
                    // Determine round type
                    if (round_num <= dist_used) begin
                        // Distracted round (Donald wins)
                        if (bet_amount <= (d_coins > g_coins ? g_coins : d_coins)) begin
                            // Calculate outcome: Donald gains bet, Gladstone loses
                            // Need to look up dp_prev[dist_used-1][d_coins+bet]
                            // Check if dist_used > 0
                            if (dist_used > 0) begin
                                if ((d_coins + bet_amount) <= 1000) begin
                                    candidate_value <= dp_prev[dist_used - 1][d_coins + bet_amount];
                                    // Update best_value
                                    if (dp_prev[dist_used - 1][d_coins + bet_amount] > best_value) begin
                                        best_value <= dp_prev[dist_used - 1][d_coins + bet_amount];
                                    end
                                end
                            end
                            bet_amount <= bet_amount + 10'd1;
                        end else begin
                            // Finished all bets
                            dp_curr[dist_used][g_idx] <= best_value;
                            state <= COMPUTE_DONALD;
                            g_idx <= g_idx + 10'd1;
                        end
                    end else begin
                        // Normal round (Gladstone wins)
                        if (bet_amount <= (d_coins > g_coins ? g_coins : d_coins)) begin
                            // Calculate outcome: Donald loses bet, Gladstone gains
                            // Need to look up dp_prev[dist_used][d_coins-bet]
                            if ((d_coins >= bet_amount) && (d_coins - bet_amount >= 10'd0)) begin
                                if (dist_used <= k) begin
                                    candidate_value <= dp_prev[dist_used][d_coins - bet_amount];
                                    // Update best_value (minimize)
                                    if (bet_amount == 10'd1) begin
                                        best_value <= dp_prev[dist_used][d_coins - 10'd1];
                                    end else if (dp_prev[dist_used][d_coins - bet_amount] < best_value) begin
                                        best_value <= dp_prev[dist_used][d_coins - bet_amount];
                                    end
                                end
                            end
                            bet_amount <= bet_amount + 10'd1;
                        end else begin
                            // Finished all bets
                            dp_curr[dist_used][g_idx] <= best_value;
                            state <= COMPUTE_DONALD;
                            g_idx <= g_idx + 10'd1;
                        end
                    end
                end

                NEXT_STATE: begin
                    // Move to next round
                    // Copy dp_curr to dp_prev
                    for (i = 0; i < 51; i = i + 1) begin
                        for (j = 0; j < 1001; j = j + 1) begin
                            dp_prev[i][j] <= dp_curr[i][j];
                            dp_curr[i][j] <= 11'd0; // Reset for next iteration
                        end
                    end
                    round_num <= round_num + 6'd1;
                    dist_used <= 6'd0;
                    dist_idx <= 6'd0;
                    g_idx <= 10'd0;
                    if (round_num >= n) begin
                        state <= FINISH;
                    end else begin
                        state <= COMPUTE_DONALD;
                    end
                end

                FINISH: begin
                    // Result is dp_prev[k][g_init] with initial Donald coins
                    // Actually, final state is dp_prev[k][g_init] for any Donald coins
                    // The result for initial d_coins and g_coins is computed
                    // We need to find dp_curr[d_init][g_init] from last round
                    // Since we copied to dp_prev at end, use dp_prev
                    result <= dp_prev[k][g_init];
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule