module TrashGame(
    input clk,
    input rst_n,
    input start,
    input [51:0][3:0] deck,
    output reg [1:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] STATE_IDLE      = 3'd0;
    localparam [2:0] STATE_RESET     = 3'd1;
    localparam [2:0] STATE_DRAW      = 3'd2;
    localparam [2:0] STATE_PROCESS   = 3'd3;
    localparam [2:0] STATE_CHECK_WIN = 3'd4;
    localparam [2:0] STATE_FINISH    = 3'd5;

    // Game constants
    localparam [4:0] MAX_CYCLES      = 5'd52;
    localparam [3:0] NUM_SLOTS       = 4'd10;

    // Registers
    reg [2:0] state, next_state;
    reg [5:0] deck_idx;            // Current deck index (0-51)
    reg [1:0] active_player;       // 0=Theta, 1=Friend
    reg [4:0] cycle_count;         // Cycle counter
    reg [3:0] theta_slots [0:9];   // Status: 0=empty, 1=face-down, 2=face-up/filled
    reg [3:0] friend_slots [0:9];  // Status: 0=empty, 1=face-down, 2=face-up/filled
    reg [3:0] current_card;        // Currently drawn card
    reg [3:0] selected_slot;       // Slot selected for current turn
    reg [3:0] card_value;          // Card value (0-13)
    reg win_detected;              // Win flag
    reg [3:0] i;                   // Loop counter
    reg [3:0] temp_count;          // Temporary counter
    reg [3:0] lowest_empty;        // Lowest empty slot for Friend

    // Result encoding
    localparam [1:0] RES_THETA_WINS = 2'd0;
    localparam [1:0] RES_FRIEND_WINS = 2'd1;
    localparam [1:0] RES_DRAW_ERROR = 2'd2;
    localparam [1:0] RES_INVALID = 2'd3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            result <= RES_INVALID;
            done <= 1'b0;
            deck_idx <= 6'd0;
            active_player <= 2'd0;
            cycle_count <= 5'd0;
            win_detected <= 1'b0;
            current_card <= 4'd0;
            selected_slot <= 4'd0;
            card_value <= 4'd0;
            temp_count <= 4'd0;
            lowest_empty <= 4'd0;
            // Initialize all slots to 1 (face-down)
            for (i = 0; i < 10; i = i + 1) begin
                theta_slots[i] <= 4'd1;
                friend_slots[i] <= 4'd1;
            end
        end else begin
            case (state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    result <= RES_INVALID;
                    if (start) begin
                        state <= STATE_RESET;
                    end
                end

                STATE_RESET: begin
                    // Reset all game variables
                    deck_idx <= 6'd20;  // Start drawing from draw pile
                    active_player <= 2'd0;  // Theta starts
                    cycle_count <= 5'd0;
                    win_detected <= 1'b0;
                    result <= RES_INVALID;
                    // Reset slots to face-down
                    for (i = 0; i < 10; i = i + 1) begin
                        theta_slots[i] <= 4'd1;
                        friend_slots[i] <= 4'd1;
                    end
                    state <= STATE_DRAW;
                end

                STATE_DRAW: begin
                    if (deck_idx >= 6'd52 || cycle_count >= MAX_CYCLES) begin
                        // Deck exhausted or too many cycles
                        result <= RES_DRAW_ERROR;
                        state <= STATE_FINISH;
                    end else begin
                        current_card <= deck[deck_idx];
                        card_value <= deck[deck_idx];
                        deck_idx <= deck_idx + 6'd1;
                        cycle_count <= cycle_count + 5'd1;
                        state <= STATE_PROCESS;
                    end
                end

                STATE_PROCESS: begin
                    // Check for Q(11) or K(12) - discard and switch player
                    if (card_value == 4'd11 || card_value == 4'd12) begin
                        active_player <= active_player + 2'd1;
                        state <= STATE_DRAW;
                    end
                    // Check for J(10) - special logic
                    else if (card_value == 4'd10) begin
                        if (active_player == 2'd0) begin
                            // Theta: Minimize unfilled slots (most face-down)
                            temp_count <= 4'd0;
                            selected_slot <= 4'd0;
                            // Find slot with most face-down cards (max unfilled)
                            // Since we only track status, we count non-filled slots
                            // Strategy: choose slot with status=1 (face-down)
                            // Start from slot 0, find first face-down
                            for (i = 0; i < 10; i = i + 1) begin
                                if (theta_slots[i] == 4'd1) begin
                                    selected_slot <= i;
                                end
                            end
                            // Mark slot as filled
                            theta_slots[selected_slot] <= 4'd2;
                        end else begin
                            // Friend: Always fill lowest unfilled slot
                            lowest_empty <= 4'd0;
                            for (i = 0; i < 10; i = i + 1) begin
                                if (friend_slots[i] == 4'd1 && lowest_empty == 4'd0) begin
                                    lowest_empty <= i;
                                end
                            end
                            friend_slots[lowest_empty] <= 4'd2;
                        end
                        state <= STATE_CHECK_WIN;
                    end
                    // Check for A-T (0-9)
                    else if (card_value <= 4'd9) begin
                        // Map card to slot
                        selected_slot <= card_value[3:0];
                        
                        // Check if slot is already filled
                        if (active_player == 2'd0) begin
                            // Theta's turn
                            if (theta_slots[card_value[3:0]] == 4'd2) begin
                                // Slot already filled - discard
                                active_player <= active_player + 2'd1;
                                state <= STATE_DRAW;
                            end else begin
                                // Uncover and place card
                                if (theta_slots[card_value[3:0]] == 4'd1) begin
                                    // Face-down card uncovered
                                    // Place drawn card in this slot (status becomes 2)
                                    theta_slots[card_value[3:0]] <= 4'd2;
                                end else begin
                                    // Empty slot, just fill it
                                    theta_slots[card_value[3:0]] <= 4'd2;
                                end
                                state <= STATE_CHECK_WIN;
                            end
                        end else begin
                            // Friend's turn
                            if (friend_slots[card_value[3:0]] == 4'd2) begin
                                // Slot already filled - discard
                                active_player <= active_player + 2'd1;
                                state <= STATE_DRAW;
                            end else begin
                                // Uncover and place card
                                if (friend_slots[card_value[3:0]] == 4'd1) begin
                                    friend_slots[card_value[3:0]] <= 4'd2;
                                end else begin
                                    friend_slots[card_value[3:0]] <= 4'd2;
                                end
                                state <= STATE_CHECK_WIN;
                            end
                        end
                    end else begin
                        // Invalid card value
                        result <= RES_DRAW_ERROR;
                        state <= STATE_FINISH;
                    end
                end

                STATE_CHECK_WIN: begin
                    // Check if player has all slots filled (status=2)
                    temp_count <= 4'd0;
                    win_detected <= 1'b0;
                    
                    if (active_player == 2'd0) begin
                        // Check Theta
                        for (i = 0; i < 10; i = i + 1) begin
                            if (theta_slots[i] == 4'd2) begin
                                temp_count <= temp_count + 4'd1;
                            end
                        end
                    end else begin
                        // Check Friend
                        for (i = 0; i < 10; i = i + 1) begin
                            if (friend_slots[i] == 4'd2) begin
                                temp_count <= temp_count + 4'd1;
                            end
                        end
                    end
                    
                    // Need to check count in next cycle
                    // Use a flag to check in next state
                    if ((active_player == 2'd0 && temp_count == 4'd10) || 
                        (active_player == 2'd1 && temp_count == 4'd10)) begin
                        win_detected <= 1'b1;
                    end
                    
                    // Move to finish or next turn
                    if (win_detected) begin
                        if (active_player == 2'd0) begin
                            result <= RES_THETA_WINS;
                        end else begin
                            result <= RES_FRIEND_WINS;
                        end
                        state <= STATE_FINISH;
                    end else begin
                        // Switch player if no win
                        active_player <= active_player + 2'd1;
                        state <= STATE_DRAW;
                    end
                end

                STATE_FINISH: begin
                    done <= 1'b1;
                    state <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule