module tournament_scheduler(
    input clk,
    input rst_n,
    input start,
    input [3:0] n_in,
    input [3:0] m_in,
    output reg [5:0] round_index,
    output reg [4:0] game_count,
    output reg [4:0] player1_idx,
    output reg [4:0] player2_idx,
    output reg output_valid,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam SETUP = 3'b001;
    localparam GEN_ROUND = 3'b010;
    localparam OUTPUT_GAME = 3'b011;
    localparam NEXT_ROUND = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    reg [2:0] next_state;

    // Internal Registers
    reg [4:0] P;            // Total players (max 16)
    reg [3:0] half_P;       // P/2 (max 8)
    reg [5:0] max_rounds;   // Max rounds to generate
    reg [5:0] round_loop;   // Counter for completed rounds
    reg [3:0] pair_loop;    // Counter for pairs in a round (also used for rotation)
    reg [4:0] game_loop;    // Counter for game output count in round (and array fill)

    // Rotation Array (Unpacked)
    reg [3:0] player_rotation [15:1];
    reg [3:0] temp_rot;     // Temp storage for rotation

    // Team calculation combinational logic
    reg [3:0] team1;
    reg [3:0] team2;

    always @(*) begin
        // Default values
        team1 = 0;
        team2 = 0;

        // Calculate current pair indices based on state
        if (state == GEN_ROUND) begin
            // p1 is pair_loop (0 to P/2 - 1)
            // p2 is from array: index P - 1 - pair_loop
            // Array indices are 1-based.
            // P - 1 - pair_loop ranges from P-1 down to P - half_P.
            // Ensure bounds: P - 1 - pair_loop >= 1 (true since pair_loop < half_P <= P/2)
            // If P=1, half_P=0, GEN_ROUND not entered.

            // Extract indices
            reg [3:0] p1_idx;
            reg [3:0] p2_idx;

            p1_idx = pair_loop; // Player 0, 1, 2...
            p2_idx = player_rotation[P - 1 - pair_loop];

            // Calculate teams based on n_in
            case (n_in)
                1: begin
                    team1 = p1_idx;
                    team2 = p2_idx;
                end
                2: begin
                    team1 = p1_idx >> 1;
                    team2 = p2_idx >> 1;
                end
                3: begin
                    // Division by 3 approximation for small numbers
                    if (p1_idx < 3) team1 = 0;
                    else if (p1_idx < 6) team1 = 1;
                    else if (p1_idx < 9) team1 = 2;
                    else if (p1_idx < 12) team1 = 3;
                    else team1 = 4;

                    if (p2_idx < 3) team2 = 0;
                    else if (p2_idx < 6) team2 = 1;
                    else if (p2_idx < 9) team2 = 2;
                    else if (p2_idx < 12) team2 = 3;
                    else team2 = 4;
                end
                4: begin
                    team1 = p1_idx >> 2;
                    team2 = p2_idx >> 2;
                end
                default: begin
                    team1 = p1_idx;
                    team2 = p2_idx;
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? SETUP : IDLE;

            SETUP: begin
                // Loop until array is filled
                if (game_loop < P - 1) next_state = SETUP;
                else next_state = GEN_ROUND;
            end

            GEN_ROUND: begin
                if (pair_loop >= half_P) begin
                    next_state = NEXT_ROUND;
                end else begin
                    // Check validity
                    if (team1 != team2) next_state = OUTPUT_GAME;
                    else next_state = GEN_ROUND; // Skip invalid pair
                end
            end

            OUTPUT_GAME: next_state = GEN_ROUND;

            NEXT_ROUND: begin
                // Rotation loop control
                // pair_loop acts as counter: 0 -> 1 -> ... -> P-1 -> P (done)
                // If pair_loop < P-1: Still rotating
                // If pair_loop == P-1: Last shift step
                // If pair_loop == P: Rotation complete, check rounds

                if (pair_loop < P - 1) next_state = NEXT_ROUND;
                else if (pair_loop == P - 1) next_state = NEXT_ROUND; // Wait for finalization
                else begin // pair_loop == P (done)
                    if (round_loop + 1 >= max_rounds) next_state = DONE;
                    else next_state = GEN_ROUND;
                end
            end

            DONE: next_state = DONE;

            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            round_index <= 0;
            game_count <= 0;
            output_valid <= 0;
            done <= 0;
            P <= 0;
            half_P <= 0;
            max_rounds <= 0;
            round_loop <= 0;
            pair_loop <= 0;
            game_loop <= 0;
            player1_idx <= 0;
            player2_idx <= 0;
        end else begin
            state <= next_state;
            output_valid <= 0; // Default deassert
            done <= 0;

            case (state)
                IDLE: begin
                    if (start) begin
                        game_loop <= 0; // Use for SETUP loop
                        round_loop <= 0;
                        round_index <= 0;
                        game_count <= 0;
                    end
                end

                SETUP: begin
                    if (game_loop == 0) begin
                        // Initialize parameters
                        P <= n_in * m_in;
                        half_P <= (n_in * m_in) >> 1;
                        if ((n_in * m_in)[0])
                            max_rounds <= n_in * m_in;
                        else
                            max_rounds <= (n_in * m_in) - 1;
                        // Init first element
                        player_rotation[1] <= 1;
                        game_loop <= 1;
                    end else if (game_loop < P - 1) begin
                        // Fill array indices 2..P-1
                        player_rotation[game_loop + 1] <= game_loop + 1;
                        game_loop <= game_loop + 1;
                    end
                    // If game_loop == P-1 (or P=1), we stay in SETUP until next_state moves us out.
                end

                GEN_ROUND: begin
                    if (pair_loop >= half_P) begin
                        // Round generation done, prepare for rotation
                        pair_loop <= 0;
                    end else begin
                        if (team1 != team2) begin
                            // Valid pair - will transition to OUTPUT_GAME
                            // We don't increment pair_loop here, OUTPUT_GAME does
                        end else begin
                            // Invalid pair - skip immediately
                            pair_loop <= pair_loop + 1;
                            // Keep game_count same (game not output)
                        end
                    end
                end

                OUTPUT_GAME: begin
                    // Output current game
                    output_valid <= 1;
                    player1_idx <= pair_loop;
                    player2_idx <= player_rotation[P - 1 - pair_loop];
                    game_count <= game_count + 1;

                    // Move to next pair
                    pair_loop <= pair_loop + 1;
                end

                NEXT_ROUND: begin
                    // Rotate array logic
                    if (pair_loop == 0) begin
                        // First step: save last element
                        if (P > 1) temp_rot <= player_rotation[P - 1];
                        // If P > 2, start shifting
                        if (P > 2) player_rotation[P - 1] <= player_rotation[P - 2];
                        pair_loop <= 1;
                    end else if (pair_loop < P - 1) begin
                        // Shift loop
                        player_rotation[P - pair_loop] <= player_rotation[P - pair_loop - 1];
                        pair_loop <= pair_loop + 1;
                    end else if (pair_loop == P - 1) begin
                        // Final step: move temp to first, update counters
                        player_rotation[1] <= temp_rot;
                        round_loop <= round_loop + 1;
                        round_index <= round_index + 1;
                        game_count <= 0;
                        pair_loop <= P; // Mark rotation as done
                    end
                    // If pair_loop == P, we wait for transition to GEN_ROUND or DONE
                end

                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule