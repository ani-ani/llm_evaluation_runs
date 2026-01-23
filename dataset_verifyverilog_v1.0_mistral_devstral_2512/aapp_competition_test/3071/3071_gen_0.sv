module schedule_generator(
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    input [4:0] m,
    output reg valid,
    output reg [9:0] round,
    output reg [9:0] p1,
    output reg [9:0] p2,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] INIT    = 3'd1;
    localparam [2:0] SCHED   = 3'd2;
    localparam [2:0] OUTPUT  = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [9:0] current_round;
    reg [9:0] current_p1, current_p2;
    reg [9:0] game_counter;
    reg [9:0] player_counter;
    reg [9:0] team_counter;
    reg [9:0] opponent_counter;
    reg [9:0] max_games;
    reg [9:0] max_players;
    reg [9:0] max_teams;
    reg [9:0] played [0:99];
    reg [9:0] scheduled [0:99];
    reg [9:0] round_games [0:99];
    reg [9:0] round_game_count;
    reg found_opponent;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            current_round <= 10'd0;
            current_p1 <= 10'd0;
            current_p2 <= 10'd0;
            game_counter <= 10'd0;
            player_counter <= 10'd0;
            team_counter <= 10'd0;
            opponent_counter <= 10'd0;
            max_games <= 10'd0;
            max_players <= 10'd0;
            max_teams <= 10'd0;
            round_game_count <= 10'd0;
            valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            found_opponent <= 1'b0;

            // Initialize played matrix
            integer i;
            for (i = 0; i < 100; i = i + 1) begin
                played[i] <= 10'd0;
                scheduled[i] <= 10'd0;
                round_games[i] <= 10'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                valid <= 1'b0;
                cycle_count <= 8'd0;
                if (start) begin
                    next_state = INIT;
                end else begin
                    next_state = IDLE;
                end
            end

            INIT: begin
                // Calculate max values
                max_players = {5'd0, n};
                max_teams = {5'd0, m};
                max_games = max_players * max_teams / 2;

                // Initialize played matrix
                integer i, j;
                for (i = 0; i < 100; i = i + 1) begin
                    played[i] <= 10'd0;
                    scheduled[i] <= 10'd0;
                    round_games[i] <= 10'd0;
                end

                current_round <= 10'd1;
                game_counter <= 10'd0;
                round_game_count <= 10'd0;
                next_state = SCHED;
            end

            SCHED: begin
                cycle_count <= cycle_count + 8'd1;
                
                // Check if all games are scheduled
                if (game_counter >= max_games || cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end else begin
                    // Try to schedule a game
                    found_opponent = 1'b0;
                    
                    // Iterate through all players
                    for (team_counter = 10'd0; team_counter < max_teams; team_counter = team_counter + 10'd1) begin
                        for (player_counter = 10'd0; player_counter < max_players; player_counter = player_counter + 10'd1) begin
                            current_p1 = {team_counter[4:0], player_counter[4:0]};
                            
                            // Check if player has played all opponents
                            for (opponent_counter = 10'd0; opponent_counter < max_players * max_teams; opponent_counter = opponent_counter + 10'd1) begin
                                if (opponent_counter != current_p1 && 
                                    (played[current_p1] & (10'd1 << opponent_counter)) == 10'd0 &&
                                    (scheduled[current_p1] & (10'd1 << opponent_counter)) == 10'd0) begin
                                    
                                    // Check if opponent is available
                                    if ((scheduled[opponent_counter] & (10'd1 << current_p1)) == 10'd0) begin
                                        current_p2 = opponent_counter;
                                        found_opponent = 1'b1;
                                        break;
                                    end
                                end
                            end
                            
                            if (found_opponent) begin
                                break;
                            end
                        end
                        
                        if (found_opponent) begin
                            break;
                        end
                    end
                    
                    if (found_opponent) begin
                        // Schedule the game
                        scheduled[current_p1] = scheduled[current_p1] | (10'd1 << current_p2);
                        scheduled[current_p2] = scheduled[current_p2] | (10'd1 << current_p1);
                        round_games[round_game_count] = {current_p1, current_p2};
                        round_game_count = round_game_count + 10'd1;
                        game_counter = game_counter + 10'd1;
                    end else begin
                        // No more games can be scheduled in this round
                        next_state = OUTPUT;
                    end
                end
            end

            OUTPUT: begin
                if (round_game_count > 10'd0) begin
                    valid <= 1'b1;
                    p1 <= round_games[0][9:0];
                    p2 <= round_games[0][19:10];
                    round <= current_round;
                    
                    // Shift remaining games
                    integer i;
                    for (i = 0; i < 99; i = i + 1) begin
                        round_games[i] <= round_games[i + 1];
                    end
                    round_games[99] <= 10'd0;
                    round_game_count = round_game_count - 10'd1;
                end else begin
                    valid <= 1'b0;
                    current_round = current_round + 10'd1;
                    next_state = SCHED;
                end
            end

            DONE_STATE: begin
                done <= 1'b1;
                valid <= 1'b0;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
                done <= 1'b0;
                valid <= 1'b0;
            end
        endcase
    end

endmodule