module ExplodingKittens(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] N,
    input wire [4:0] E,
    input wire [4:0] D,
    input wire [15:0] e_locs [0:15],
    input wire [15:0] d_locs [0:15],
    output reg [4:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] SIMULATE = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state, next_state;

    // Player state
    reg [15:0] active_players;
    reg [15:0] has_defuse;
    reg [4:0] player_count;
    reg [4:0] current_player;

    // Event tracking
    reg [4:0] total_events;
    reg [4:0] event_index;
    reg [4:0] card_counter;

    // Event storage (sorted)
    reg [15:0] sorted_events [0:31];
    reg [15:0] event_types [0:31]; // 0: Exploding Kitten, 1: Defuse
    reg [4:0] event_kitten_index [0:31];
    reg [4:0] event_defuse_index [0:31];

    // Temporary registers for sorting
    reg [15:0] temp_events [0:31];
    reg [15:0] temp_types [0:31];
    reg [4:0] temp_kitten_idx [0:31];
    reg [4:0] temp_defuse_idx [0:31];

    // Cycle counter for safety
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1024;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            result <= 5'd0;
            cycle_count <= 10'd0;
            
            // Reset player state
            active_players <= 16'd0;
            has_defuse <= 16'd0;
            player_count <= 5'd0;
            current_player <= 5'd0;
            
            // Reset event tracking
            total_events <= 5'd0;
            event_index <= 5'd0;
            card_counter <= 5'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 5'd0;
                    cycle_count <= 10'd0;
                    
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    // Initialize player state
                    active_players <= {16{N[4:0]}};
                    has_defuse <= 16'd0;
                    player_count <= N;
                    current_player <= 5'd0;
                    
                    // Initialize event tracking
                    total_events <= E + D;
                    event_index <= 5'd0;
                    card_counter <= 5'd0;
                    
                    // Copy events to temp storage
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < E) begin
                            temp_events[i] <= e_locs[i];
                            temp_types[i] <= 1'b0;
                            temp_kitten_idx[i] <= i;
                            temp_defuse_idx[i] <= 5'd0;
                        end
                        if (i < D) begin
                            temp_events[E + i] <= d_locs[i];
                            temp_types[E + i] <= 1'b1;
                            temp_kitten_idx[E + i] <= 5'd0;
                            temp_defuse_idx[E + i] <= i;
                        end
                    end
                    
                    next_state <= SORT;
                end

                SORT: begin
                    // Bubble sort implementation
                    reg [4:0] j, k;
                    reg [15:0] temp_val;
                    reg temp_type;
                    reg [4:0] temp_k_idx, temp_d_idx;
                    
                    for (j = 0; j < total_events - 1; j = j + 1) begin
                        for (k = 0; k < total_events - j - 1; k = k + 1) begin
                            if (temp_events[k] > temp_events[k + 1]) begin
                                // Swap positions
                                temp_val <= temp_events[k];
                                temp_events[k] <= temp_events[k + 1];
                                temp_events[k + 1] <= temp_val;
                                
                                // Swap types
                                temp_type <= temp_types[k];
                                temp_types[k] <= temp_types[k + 1];
                                temp_types[k + 1] <= temp_type;
                                
                                // Swap kitten indices
                                temp_k_idx <= temp_kitten_idx[k];
                                temp_kitten_idx[k] <= temp_kitten_idx[k + 1];
                                temp_kitten_idx[k + 1] <= temp_k_idx;
                                
                                // Swap defuse indices
                                temp_d_idx <= temp_defuse_idx[k];
                                temp_defuse_idx[k] <= temp_defuse_idx[k + 1];
                                temp_defuse_idx[k + 1] <= temp_d_idx;
                            end
                        end
                    end
                    
                    // Copy sorted events to main storage
                    for (j = 0; j < total_events; j = j + 1) begin
                        sorted_events[j] <= temp_events[j];
                        event_types[j] <= temp_types[j];
                        event_kitten_index[j] <= temp_kitten_idx[j];
                        event_defuse_index[j] <= temp_defuse_idx[j];
                    end
                    
                    next_state <= SIMULATE;
                end

                SIMULATE: begin
                    cycle_count <= cycle_count + 10'd1;
                    
                    // Check for timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                        result <= 5'd31;
                    end else begin
                        // Check if we have a winner
                        reg [4:0] active_count;
                        reg [4:0] last_active;
                        integer p;
                        
                        active_count = 5'd0;
                        last_active = 5'd0;
                        for (p = 0; p < 16; p = p + 1) begin
                            if (active_players[p]) begin
                                active_count = active_count + 5'd1;
                                last_active = p;
                            end
                        end
                        
                        if (active_count == 1) begin
                            result <= last_active;
                            next_state <= FINISH;
                        end else if (active_count == 0) begin
                            result <= 5'd31;
                            next_state <= FINISH;
                        end else begin
                            // Find next active player
                            reg [4:0] next_player;
                            reg found;
                            
                            found = 1'b0;
                            next_player = current_player + 5'd1;
                            while (!found && next_player < 16) begin
                                if (active_players[next_player] && next_player < N) begin
                                    found = 1'b1;
                                end else begin
                                    next_player = next_player + 5'd1;
                                end
                            end
                            
                            if (!found) begin
                                next_player = 5'd0;
                                while (!found && next_player < current_player) begin
                                    if (active_players[next_player] && next_player < N) begin
                                        found = 1'b1;
                                    end else begin
                                        next_player = next_player + 5'd1;
                                    end
                                end
                            end
                            
                            current_player <= next_player;
                            
                            // Draw phase
                            card_counter <= card_counter + 5'd1;
                            
                            // Check if current card matches next event
                            if (event_index < total_events && card_counter == sorted_events[event_index]) begin
                                // Process event
                                if (event_types[event_index] == 1'b0) begin
                                    // Exploding Kitten event
                                    if (has_defuse[current_player]) begin
                                        // Defuse the kitten
                                        has_defuse[current_player] <= 1'b0;
                                        
                                        // Remove the corresponding defuse card
                                        reg [4:0] defuse_to_remove;
                                        defuse_to_remove = event_kitten_index[event_index] % D;
                                        
                                        // Mark this defuse as used by setting its position to max
                                        integer d;
                                        for (d = 0; d < D; d = d + 1) begin
                                            if (event_defuse_index[event_index] == defuse_to_remove) begin
                                                sorted_events[event_index] <= 16'hFFFF;
                                                event_types[event_index] <= 1'b0;
                                            end
                                        end
                                    end else begin
                                        // Player explodes
                                        active_players[current_player] <= 1'b0;
                                        player_count <= player_count - 5'd1;
                                    end
                                    
                                    // Remove this event
                                    event_index <= event_index + 5'd1;
                                end else begin
                                    // Defuse event
                                    if (!has_defuse[current_player]) begin
                                        has_defuse[current_player] <= 1'b1;
                                        event_index <= event_index + 5'd1;
                                    end
                                end
                            end
                            
                            // Check for winner again after processing event
                            active_count = 5'd0;
                            last_active = 5'd0;
                            for (p = 0; p < 16; p = p + 1) begin
                                if (active_players[p]) begin
                                    active_count = active_count + 5'd1;
                                    last_active = p;
                                end
                            end
                            
                            if (active_count == 1) begin
                                result <= last_active;
                                next_state <= FINISH;
                            end else if (active_count == 0) begin
                                result <= 5'd31;
                                next_state <= FINISH;
                            end else if (event_index >= total_events) begin
                                // No more events, no winner
                                result <= 5'd31;
                                next_state <= FINISH;
                            end else begin
                                next_state <= SIMULATE;
                            end
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    result <= 5'd0;
                end
            endcase
        end
    end

endmodule