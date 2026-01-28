module card_game_betting(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [9:0] d_init,
    input wire [9:0] g_init,
    input wire [5:0] n,
    input wire [5:0] k,
    output reg [10:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100000;

    // DP table dimensions
    localparam [5:0] MAX_ROUNDS = 6'd50;
    localparam [5:0] MAX_DISTRACTIONS = 6'd50;
    localparam [9:0] MAX_COINS = 10'd1000;

    // DP table storage (current and next round)
    reg [10:0] dp_current [0:MAX_ROUNDS][0:MAX_DISTRACTIONS][0:MAX_COINS];
    reg [10:0] dp_next [0:MAX_ROUNDS][0:MAX_DISTRACTIONS][0:MAX_COINS];

    // Round and distraction counters
    reg [5:0] current_round;
    reg [5:0] current_distractions;
    reg [9:0] current_d_coins;
    reg [9:0] current_g_coins;

    // Bet amount counter
    reg [9:0] bet_amount;
    reg [10:0] max_value;
    reg [10:0] min_value;

    // Initialize DP table
    integer i, j, k_idx, d_idx, g_idx;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 11'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            current_round <= 6'd0;
            current_distractions <= 6'd0;
            current_d_coins <= 10'd0;
            current_g_coins <= 10'd0;
            bet_amount <= 10'd0;
            max_value <= 11'd0;
            min_value <= 11'd1023;
            
            // Initialize DP table
            for (i = 0; i <= MAX_ROUNDS; i = i + 1) begin
                for (j = 0; j <= MAX_DISTRACTIONS; j = j + 1) begin
                    for (d_idx = 0; d_idx <= MAX_COINS; d_idx = d_idx + 1) begin
                        for (g_idx = 0; g_idx <= MAX_COINS; g_idx = g_idx + 1) begin
                            if (i == 0 && j == 0) begin
                                dp_current[i][j][d_idx] <= d_idx;
                            end else begin
                                dp_current[i][j][d_idx] <= 11'd0;
                            end
                        end
                    end
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    // Initialize for computation
                    current_round <= 6'd0;
                    current_distractions <= 6'd0;
                    current_d_coins <= 10'd0;
                    current_g_coins <= 10'd0;
                    state <= COMPUTE;
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if computation should finish
                    if (current_round == n && current_distractions == k && 
                        current_d_coins == d_init && current_g_coins == g_init) begin
                        state <= FINISH;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        // Compute DP for current state
                        if (current_round == 0 && current_distractions == 0) begin
                            // Base case: already initialized
                            current_d_coins <= current_d_coins + 10'd1;
                            if (current_d_coins > d_init) begin
                                current_d_coins <= 10'd0;
                                current_g_coins <= current_g_coins + 10'd1;
                                if (current_g_coins > g_init) begin
                                    current_g_coins <= 10'd0;
                                    current_distractions <= current_distractions + 6'd1;
                                    if (current_distractions > k) begin
                                        current_distractions <= 6'd0;
                                        current_round <= current_round + 6'd1;
                                    end
                                end
                            end
                        end else if (current_distractions > 0 && current_distractions <= current_round) begin
                            // Donald can win (distracted round)
                            if (bet_amount == 0) begin
                                max_value <= 11'd0;
                                bet_amount <= 10'd1;
                            end else begin
                                // Compute max over possible bets
                                if (bet_amount <= current_d_coins && bet_amount <= current_g_coins) begin
                                    if (dp_current[current_round-1][current_distractions-1][current_d_coins+bet_amount] > max_value) begin
                                        max_value <= dp_current[current_round-1][current_distractions-1][current_d_coins+bet_amount];
                                    end
                                end
                                bet_amount <= bet_amount + 10'd1;
                                if (bet_amount > current_d_coins || bet_amount > current_g_coins || bet_amount > 10'd100) begin
                                    dp_next[current_round][current_distractions][current_d_coins] <= max_value;
                                    bet_amount <= 10'd0;
                                    current_d_coins <= current_d_coins + 10'd1;
                                    if (current_d_coins > MAX_COINS) begin
                                        current_d_coins <= 10'd0;
                                        current_g_coins <= current_g_coins + 10'd1;
                                        if (current_g_coins > MAX_COINS) begin
                                            current_g_coins <= 10'd0;
                                            current_distractions <= current_distractions + 6'd1;
                                            if (current_distractions > current_round) begin
                                                current_distractions <= 6'd0;
                                                current_round <= current_round + 6'd1;
                                                // Copy next to current
                                                for (i = 0; i <= MAX_ROUNDS; i = i + 1) begin
                                                    for (j = 0; j <= MAX_DISTRACTIONS; j = j + 1) begin
                                                        for (d_idx = 0; d_idx <= MAX_COINS; d_idx = d_idx + 1) begin
                                                            dp_current[i][j][d_idx] <= dp_next[i][j][d_idx];
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end else begin
                            // Gladstone wins (normal round)
                            if (bet_amount == 0) begin
                                min_value <= 11'd1023;
                                bet_amount <= 10'd1;
                            end else begin
                                // Compute min over possible bets
                                if (bet_amount <= current_d_coins && bet_amount <= current_g_coins) begin
                                    if (current_d_coins >= bet_amount) begin
                                        if (dp_current[current_round-1][current_distractions][current_d_coins-bet_amount] < min_value) begin
                                            min_value <= dp_current[current_round-1][current_distractions][current_d_coins-bet_amount];
                                        end
                                    end
                                end
                                bet_amount <= bet_amount + 10'd1;
                                if (bet_amount > current_d_coins || bet_amount > current_g_coins || bet_amount > 10'd100) begin
                                    if (min_value == 11'd1023) begin
                                        dp_next[current_round][current_distractions][current_d_coins] <= 11'd0;
                                    end else begin
                                        dp_next[current_round][current_distractions][current_d_coins] <= min_value;
                                    end
                                    bet_amount <= 10'd0;
                                    current_d_coins <= current_d_coins + 10'd1;
                                    if (current_d_coins > MAX_COINS) begin
                                        current_d_coins <= 10'd0;
                                        current_g_coins <= current_g_coins + 10'd1;
                                        if (current_g_coins > MAX_COINS) begin
                                            current_g_coins <= 10'd0;
                                            current_distractions <= current_distractions + 6'd1;
                                            if (current_distractions > current_round) begin
                                                current_distractions <= 6'd0;
                                                current_round <= current_round + 6'd1;
                                                // Copy next to current
                                                for (i = 0; i <= MAX_ROUNDS; i = i + 1) begin
                                                    for (j = 0; j <= MAX_DISTRACTIONS; j = j + 1) begin
                                                        for (d_idx = 0; d_idx <= MAX_COINS; d_idx = d_idx + 1) begin
                                                            dp_current[i][j][d_idx] <= dp_next[i][j][d_idx];
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                
                FINISH: begin
                    result <= dp_current[n][k][d_init];
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule