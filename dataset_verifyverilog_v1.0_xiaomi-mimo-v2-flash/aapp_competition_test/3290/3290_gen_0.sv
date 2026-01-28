module ExplodingKittensBenchmark(
    input clk,
    input rst_n,
    input start,
    input [4:0] N,
    input [4:0] E,
    input [4:0] D,
    input [15:0] e_locs [0:15],
    input [15:0] d_locs [0:15],
    output reg [4:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] SORT_EVENTS = 4'd1;
    localparam [3:0] SETUP_PLAYERS = 4'd2;
    localparam [3:0] DRAW = 4'd3;
    localparam [3:0] PROCESS_EVENT = 4'd4;
    localparam [3:0] CHECK_WINNER = 4'd5;
    localparam [3:0] NEXT_PLAYER = 4'd6;
    localparam [3:0] FINISH = 4'd7;
    localparam [3:0] REMOVE_DEFUSE = 4'd8;
    localparam [3:0] DISCARD_HAND = 4'd9;

    reg [3:0] state, next_state;
    
    // Player array (16 max)
    reg [15:0] players_active;
    reg [15:0] players_defuse;
    reg [4:0] active_count;
    
    // Event storage (packed: type + pos)
    // type: 0=defuse, 1=exploding
    reg [16:0] events [0:31]; // 17 bits: 1 type + 16 pos
    reg [5:0] event_count; // Total events (E + D)
    reg [5:0] event_idx; // Current event pointer
    reg [15:0] current_card_pos;
    
    // Sort network variables
    reg [5:0] sort_i, sort_j;
    reg [16:0] temp_event;
    
    // Player turn variables
    reg [4:0] player_idx; // 0 to N-1
    reg [4:0] drawn_count; // Cards drawn
    reg [4:0] hand_count; // Cards in hand
    
    // Defuse removal mapping
    reg [4:0] defuse_remove_idx;
    reg [4:0] defuse_remove_count;
    
    // Cycle counter for timeout
    reg [10:0] cycle_count;
    localparam [10:0] MAX_CYCLES = 11'd1024;

    // Combinational signals
    reg [15:0] next_card_pos;
    reg is_exploding;
    reg event_available;
    reg defuse_needed;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            players_active <= 16'd0;
            players_defuse <= 16'd0;
            active_count <= 5'd0;
            event_count <= 6'd0;
            event_idx <= 6'd0;
            current_card_pos <= 16'd0;
            player_idx <= 5'd0;
            drawn_count <= 5'd0;
            hand_count <= 5'd0;
            defuse_remove_idx <= 5'd0;
            defuse_remove_count <= 5'd0;
            cycle_count <= 11'd0;
            sort_i <= 6'd0;
            sort_j <= 6'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 11'd0;
                    if (start) begin
                        state <= SORT_EVENTS;
                        event_count <= {1'b0, E} + {1'b0, D}; // E + D
                        event_idx <= 6'd0;
                        sort_i <= 6'd0;
                        sort_j <= 6'd0;
                    end
                end
                
                SORT_EVENTS: begin
                    // Initialize events array
                    if (sort_i < E) begin
                        events[sort_i] <= {1'b1, e_locs[sort_i]}; // Exploding
                        sort_i <= sort_i + 6'd1;
                    end else if (sort_i < E + D) begin
                        events[sort_i] <= {1'b0, d_locs[sort_i - E]}; // Defuse
                        sort_i <= sort_i + 6'd1;
                    end else begin
                        // Bubble sort pass
                        if (sort_i < event_count) begin
                            if (sort_j < event_count - sort_i - 6'd1) begin
                                if (events[sort_j][15:0] > events[sort_j + 6'd1][15:0]) begin
                                    temp_event <= events[sort_j];
                                    events[sort_j] <= events[sort_j + 6'd1];
                                    events[sort_j + 6'd1] <= temp_event;
                                end
                                sort_j <= sort_j + 6'd1;
                            end else begin
                                sort_j <= 6'd0;
                                sort_i <= sort_i + 6'd1;
                            end
                        end else begin
                            state <= SETUP_PLAYERS;
                            sort_i <= 6'd0;
                        end
                    end
                end
                
                SETUP_PLAYERS: begin
                    if (sort_i < N) begin
                        players_active[sort_i] <= 1'b1;
                        players_defuse[sort_i] <= 1'b0;
                        sort_i <= sort_i + 5'd1;
                    end else begin
                        active_count <= N;
                        player_idx <= 5'd0;
                        drawn_count <= 5'd0;
                        current_card_pos <= 16'd0;
                        state <= DRAW;
                    end
                end
                
                DRAW: begin
                    // Check if current player is active
                    if (player_idx < N && players_active[player_idx]) begin
                        drawn_count <= drawn_count + 5'd1;
                        // Next card position (simulate increment)
                        // Use event position as trigger
                        if (event_idx < event_count && events[event_idx][15:0] > current_card_pos) begin
                            current_card_pos <= events[event_idx][15:0];
                        end else begin
                            current_card_pos <= current_card_pos + 16'd1;
                        end
                        state <= PROCESS_EVENT;
                    end else begin
                        state <= NEXT_PLAYER;
                    end
                end
                
                PROCESS_EVENT: begin
                    // Check if event matches current position
                    event_available <= (event_idx < event_count);
                    is_exploding <= events[event_idx][16];
                    
                    if (event_idx < event_count && events[event_idx][15:0] <= current_card_pos) begin
                        if (events[event_idx][16]) begin // Exploding Kitten
                            if (players_defuse[player_idx]) begin
                                // Has defuse
                                state <= REMOVE_DEFUSE;
                                defuse_remove_count <= 5'd0;
                                // Map Kitten index to Defuse index
                                defuse_remove_idx <= event_idx % (D + 5'd1); // Simplified mapping
                            end else begin
                                // No defuse - deactivate
                                players_active[player_idx] <= 1'b0;
                                active_count <= active_count - 5'd1;
                                state <= CHECK_WINNER;
                                event_idx <= event_idx + 6'd1;
                            end
                        end else begin // Defuse Card
                            defuse_needed <= ~players_defuse[player_idx];
                            if (~players_defuse[player_idx]) begin
                                players_defuse[player_idx] <= 1'b1;
                                hand_count <= hand_count + 5'd1;
                            end
                            state <= DISCARD_HAND;
                            event_idx <= event_idx + 6'd1;
                        end
                    end else begin
                        // No event at this position
                        state <= CHECK_WINNER;
                    end
                end
                
                REMOVE_DEFUSE: begin
                    // Remove the matching Defuse card from the game
                    // Scan events to find a defuse card with same index mapping
                    if (defuse_remove_count < event_count) begin
                        if (~events[defuse_remove_count][16] && (defuse_remove_count % (D + 5'd1)) == defuse_remove_idx) begin
                            // Remove this defuse (mark as used/expired)
                            // Shift events left
                            integer k;
                            for (k = defuse_remove_count; k < event_count - 1; k = k + 1) begin
                                events[k] <= events[k + 1];
                            end
                            event_count <= event_count - 6'd1;
                            // Also need to decrement event_idx if it was after removed
                            if (event_idx > defuse_remove_count) begin
                                event_idx <= event_idx - 6'd1;
                            end
                        end
                        defuse_remove_count <= defuse_remove_count + 5'd1;
                    end else begin
                        // Defuse used, kitten discarded
                        players_defuse[player_idx] <= 1'b0;
                        hand_count <= hand_count - 5'd1; // Defuse removed from hand
                        event_idx <= event_idx + 6'd1;
                        state <= DISCARD_HAND;
                    end
                end
                
                DISCARD_HAND: begin
                    // Keep max 5 cards (only defuse matters)
                    if (hand_count > 5) begin
                        hand_count <= 5;
                        // Cap defuse to 1
                        if (players_defuse[player_idx] && hand_count > 5) begin
                            players_defuse[player_idx] <= 1'b1; // Already 1
                        end
                    end
                    state <= CHECK_WINNER;
                end
                
                CHECK_WINNER: begin
                    if (active_count == 5'd1) begin
                        // Find the winner
                        if (players_active[player_idx]) begin
                            result <= player_idx;
                        end else begin
                            // Find active player
                            integer k;
                            reg found;
                            found = 1'b0;
                            for (k = 0; k < 16; k = k + 1) begin
                                if (!found && players_active[k]) begin
                                    result <= k;
                                    found = 1'b1;
                                end
                            end
                        end
                        state <= FINISH;
                    end else if (active_count == 5'd0) begin
                        result <= 5'd31; // No winner
                        state <= FINISH;
                    end else begin
                        state <= NEXT_PLAYER;
                    end
                end
                
                NEXT_PLAYER: begin
                    // Move to next active player
                    if (player_idx < N - 5'd1) begin
                        player_idx <= player_idx + 5'd1;
                    end else begin
                        player_idx <= 5'd0;
                    end
                    hand_count <= 5'd0; // Reset hand count for next turn
                    
                    // Check if all events processed
                    if (event_idx >= event_count) begin
                        // No more events, find winner among remaining
                        if (active_count == 5'd1) begin
                            state <= CHECK_WINNER;
                        end else if (active_count > 5'd1) begin
                            // Multiple players left, no clear winner
                            result <= 5'd31;
                            state <= FINISH;
                        end else begin
                            result <= 5'd31;
                            state <= FINISH;
                        end
                    end else begin
                        state <= DRAW;
                    end
                    
                    cycle_count <= cycle_count + 11'd1;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            // Timeout protection
            if (cycle_count >= MAX_CYCLES && state != FINISH && state != IDLE) begin
                result <= 5'd31;
                state <= FINISH;
            end
        end
    end

endmodule