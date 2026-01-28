module schedule_generator (
    input clk,
    input rst_n,
    input start,
    input [4:0] n, // players per team (1-25)
    input [4:0] m, // teams (2-25)
    output reg valid,
    output reg [9:0] round,
    output reg [9:0] p1, // player1 ID: {team[4:0], player[4:0]}
    output reg [9:0] p2, // player2 ID
    output reg done
);

    // Internal state definitions
    localparam [3:0] IDLE    = 4'd0;
    localparam [3:0] INIT    = 4'd1;
    localparam [3:0] SCHED   = 4'd2;
    localparam [3:0] OUTPUT  = 4'd3;
    localparam [3:0] FINISH  = 4'd4;
    localparam [3:0] ERROR   = 4'd5;

    // Current state registers
    reg [3:0] state;
    reg [3:0] next_state;

    // Timing and counters
    reg [9:0] round_counter;
    reg [9:0] total_rounds;
    reg [9:0] output_counter;
    reg [9:0] output_count_total;
    
    // Player tracking
    reg [4:0] t1; // Team 1
    reg [4:0] p_idx1; // Player 1
    reg [4:0] t2; // Team 2
    reg [4:0] p_idx2; // Player 2
    reg [9:0] player1_id;
    reg [9:0] player2_id;
    reg [9:0] current_game_index;
    
    // Scheduling state variables
    reg [9:0] scan_player; // Currently scanning player
    reg [9:0] scan_opponent; // Currently checking opponent
    reg [9:0] opponent_found; // Found opponent for current player
    reg scan_complete; // Flag for when scan of current round is complete
    reg found_game; // Flag to indicate if any game found this round
    reg start_round_output; // Trigger output phase
    
    // BRAM for played matrix
    reg [99:0] played_matrix [0:99]; // 100x100 bit matrix
    reg [3:0] init_counter;
    reg [9:0] row_index;
    reg [9:0] col_index;
    
    // Game storage buffer (simple FIFO-like structure)
    reg [19:0] game_buffer [0:199]; // Max ~200 games (25*25*2/2=312, we handle streaming)
    reg [7:0] buffer_index;
    reg [7:0] buffer_read_index;
    
    // Cycle count to prevent hangs
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd20000;

    // Combinational logic for player ID calculation
    wire [9:0] calc_p1_id = t1 * n + p_idx1;
    wire [9:0] calc_p2_id = t2 * n + p_idx2;

    // FSM State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    if (n < 2 || n > 25 || m < 2 || m > 25) begin
                        next_state = ERROR;
                    end else begin
                        next_state = INIT;
                    end
                end
            end
            INIT: begin
                if (init_counter >= 4'd10) begin // Initialize matrix
                    next_state = SCHED;
                end else begin
                    next_state = INIT;
                end
            end
            SCHED: begin
                // Logic to schedule games for current round
                // When scan_complete and !found_game -> OUTPUT
                // When scan_complete and found_game -> still SCHED (continue this round)
                // If scan hits max players -> OUTPUT
                if (scan_complete && !found_game) begin
                    if (round_counter >= total_rounds) begin
                        next_state = FINISH;
                    end else begin
                        next_state = OUTPUT;
                    end
                end else if (scan_complete && found_game) begin
                    // Reset scan for another pass in the same round
                    next_state = SCHED;
                end else begin
                    next_state = SCHED;
                end
            end
            OUTPUT: begin
                // Stream games for the round
                if (output_counter >= output_count_total) begin
                    next_state = SCHED;
                end else begin
                    next_state = OUTPUT;
                end
            end
            FINISH: begin
                next_state = FINISH; // Stay here
            end
            ERROR: begin
                next_state = ERROR;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output and Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid <= 1'b0;
            round <= 10'd0;
            p1 <= 10'd0;
            p2 <= 10'd0;
            done <= 1'b0;
            cycle_count <= 16'd0;
            init_counter <= 4'd0;
            round_counter <= 10'd0;
            output_counter <= 10'd0;
            output_count_total <= 10'd0;
            t1 <= 5'd0;
            p_idx1 <= 5'd0;
            t2 <= 5'd0;
            p_idx2 <= 5'd0;
            scan_player <= 10'd0;
            scan_opponent <= 10'd0;
            scan_complete <= 1'b0;
            found_game <= 1'b0;
            start_round_output <= 1'b0;
            buffer_read_index <= 8'd0;
            buffer_index <= 8'd0;
            player1_id <= 10'd0;
            player2_id <= 10'd0;
            current_game_index <= 10'd0;
            // Initialize played matrix (set all to 0)
            row_index <= 10'd0;
            col_index <= 10'd0;
            total_rounds <= 10'd0;
        end else begin
            // Default outputs
            valid <= 1'b0;
            done <= 1'b0;
            
            if (state != IDLE && state != FINISH && state != ERROR) begin
                cycle_count <= cycle_count + 16'd1;
            end

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        cycle_count <= 16'd0;
                        round_counter <= 10'd0;
                        total_rounds <= ((m - 1) * n) + 1; // Heuristic for max rounds
                        init_counter <= 4'd0;
                        buffer_index <= 8'd0;
                        buffer_read_index <= 8'd0;
                        output_counter <= 10'd0;
                        output_count_total <= 10'd0;
                        row_index <= 10'd0;
                        col_index <= 10'd0;
                        t1 <= 5'd0;
                        p_idx1 <= 5'd0;
                        t2 <= 5'd0;
                        p_idx2 <= 5'd0;
                        scan_player <= 10'd0;
                        scan_opponent <= 10'd0;
                        scan_complete <= 1'b0;
                        found_game <= 1'b0;
                    end
                end

                INIT: begin
                    // Initialize played matrix to 0
                    // We unroll this slightly for speed, or use loop
                    if (init_counter < 4'd10) begin
                        for (int k = 0; k < 10; k = k + 1) begin
                            if (row_index + k < 100) begin
                                played_matrix[row_index + k] <= 100'd0;
                            end
                        end
                        row_index <= row_index + 10'd10;
                        if (row_index >= 100 - 10) begin
                            init_counter <= init_counter + 4'd1;
                            row_index <= 10'd0;
                        end
                    end
                    // Also reset game buffer
                    if (init_counter == 4'd9) begin
                        buffer_index <= 8'd0;
                        buffer_read_index <= 8'd0;
                        output_count_total <= 10'd0;
                    end
                end

                SCHED: begin
                    // Greedy scheduling loop
                    // Scan all players (0 to m*n - 1)
                    // For each player, scan opponents (0 to m*n - 1)
                    // Skip same team and already played
                    
                    if (scan_player < (m * n)) begin
                        if (scan_opponent < (m * n)) begin
                            // Check if opponent is valid
                            // 1. Different team
                            // 2. Not played yet
                            // 3. Not itself
                            
                            if (scan_opponent != scan_player && 
                                (scan_opponent / n) != (scan_player / n) && // Different team
                                !played_matrix[scan_player][scan_opponent]) begin // Not played
                                
                                // Found a valid game
                                found_game <= 1'b1;
                                
                                // Add to buffer
                                if (buffer_index < 8'd200) begin
                                    game_buffer[buffer_index] <= {scan_player, scan_opponent};
                                    buffer_index <= buffer_index + 8'd1;
                                end
                                
                                // Mark as played
                                played_matrix[scan_player][scan_opponent] <= 1'b1;
                                played_matrix[scan_opponent][scan_player] <= 1'b1;
                                
                                // Move to next player (greedy approach)
                                scan_player <= scan_player + 10'd1;
                                scan_opponent <= 10'd0;
                                
                                // Check if we filled this round completely
                                // (Simplified: continue scanning all players to fill current round)
                                
                            end else begin
                                scan_opponent <= scan_opponent + 10'd1;
                            end
                        end else begin
                            // Done scanning opponents for current player
                            scan_opponent <= 10'd0;
                            scan_player <= scan_player + 10'd1;
                        end
                    end else begin
                        // Finished scanning all players for this round
                        // Update scan_complete flag
                        if (!scan_complete) begin
                            scan_complete <= 1'b1;
                            
                            // If no game found, we are done with this round
                            // If game found, we need to reset scan for another pass?
                            // Simplified greedy: One pass per round usually sufficient for bipartite matchings
                            // If `found_game` is true, we might want to check if more can be added.
                            // For simplicity in this constrained environment, we do one scan pass per round.
                            // If we found games, we output them.
                        end
                    end

                    // Reset flags when moving out of this logic block handled by next_state
                end

                OUTPUT: begin
                    scan_complete <= 1'b0; // Reset scan flag for next round
                    
                    if (output_counter == 10'd0) begin
                        // Setup output count
                        output_count_total <= buffer_index - buffer_read_index;
                        round <= round_counter + 10'd1;
                    end

                    if (output_counter < output_count_total) begin
                        valid <= 1'b1;
                        
                        // Read from buffer
                        p1 <= game_buffer[buffer_read_index][19:10];
                        p2 <= game_buffer[buffer_read_index][9:0];
                        
                        buffer_read_index <= buffer_read_index + 8'd1;
                        output_counter <= output_counter + 10'd1;
                        found_game <= 1'b0; // Reset found flag for next round logic
                    end else begin
                        // Finished outputting this round
                        output_counter <= 10'd0;
                        buffer_read_index <= 8'd0;
                        
                        // Clear the buffer logically (or just reset index)
                        buffer_index <= 8'd0;
                        
                        // Move to next round
                        round_counter <= round_counter + 10'd1;
                        
                        // Reset scan variables
                        scan_player <= 10'd0;
                        scan_opponent <= 10'd0;
                        scan_complete <= 1'b0;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    valid <= 1'b0;
                end

                ERROR: begin
                    done <= 1'b1;
                    valid <= 1'b0;
                end
            endcase
            
            // Safety timeout
            if (cycle_count > MAX_CYCLES && state != IDLE) begin
                state <= ERROR;
                next_state <= ERROR;
            end
        end
    end

endmodule