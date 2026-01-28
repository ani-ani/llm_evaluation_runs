module TrashCardGame(
    input clk,
    input rst_n,
    input start,
    input [3:0] deck [0:51],
    output reg [1:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] DRAW      = 3'd2;
    localparam [2:0] PROCESS   = 3'd3;
    localparam [2:0] CHECK_WIN = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    // Player definitions
    localparam [0:0] THETA     = 1'b0;
    localparam [0:0] FRIEND    = 1'b1;

    // Card value definitions
    localparam [3:0] QUEEN     = 4'd11;
    localparam [3:0] KING      = 4'd12;
    localparam [3:0] JACK      = 4'd10;

    // Slot status definitions
    localparam [3:0] EMPTY     = 4'd0;
    localparam [3:0] FACE_DOWN = 4'd1;
    localparam [3:0] FILLED    = 4'd2;

    // FSM state
    reg [2:0] state, next_state;

    // Player turn
    reg [0:0] active_player;

    // Deck index
    reg [5:0] deck_idx;

    // Player slots (Theta: 0-9, Friend: 10-19)
    reg [3:0] slots [0:19];

    // Current card
    reg [3:0] current_card;

    // Cycle counter
    reg [5:0] cycle_count;
    localparam [5:0] MAX_CYCLES = 6'd52;

    // Win flags
    reg theta_win, friend_win;

    // Card to slot mapping for Ace-Ten
    function [3:0] card_to_slot(input [3:0] card);
        if (card <= 4'd4) begin
            card_to_slot = card;
        end else if (card <= 4'd9) begin
            card_to_slot = card - 4'd5;
        end else begin
            card_to_slot = 4'd0; // Invalid, will be handled
        end
    endfunction

    // Count filled slots for a player
    function [3:0] count_filled(input [3:0] slots[0:9]);
        integer i;
        reg [3:0] count;
        begin
            count = 4'd0;
            for (i = 0; i < 10; i = i + 1) begin
                if (slots[i] == FILLED) begin
                    count = count + 4'd1;
                end
            end
            count_filled = count;
        end
    endfunction

    // Count unfilled slots for Theta's strategy
    function [3:0] count_unfilled(input [3:0] slots[0:9]);
        integer i;
        reg [3:0] count;
        begin
            count = 4'd0;
            for (i = 0; i < 10; i = i + 1) begin
                if (slots[i] != FILLED) begin
                    count = count + 4'd1;
                end
            end
            count_unfilled = count;
        end
    endfunction

    // Find lowest unfilled slot for Friend
    function [3:0] find_lowest_unfilled(input [3:0] slots[0:9]);
        integer i;
        begin
            for (i = 0; i < 10; i = i + 1) begin
                if (slots[i] != FILLED) begin
                    find_lowest_unfilled = i;
                end
            end
            find_lowest_unfilled = 4'd0; // Default if all filled
        end
    endfunction

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            active_player <= THETA;
            deck_idx <= 6'd20;
            result <= 2'd0;
            done <= 1'b0;
            cycle_count <= 6'd0;
            theta_win <= 1'b0;
            friend_win <= 1'b0;

            // Initialize slots
            integer i;
            for (i = 0; i < 10; i = i + 1) begin
                slots[i] <= FACE_DOWN; // Theta's slots
                slots[i + 10] <= FACE_DOWN; // Friend's slots
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 2'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    cycle_count <= 6'd0;
                    active_player <= THETA;
                    deck_idx <= 6'd20;
                    next_state <= DRAW;
                end

                DRAW: begin
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end else begin
                        current_card <= deck[deck_idx];
                        deck_idx <= deck_idx + 6'd1;
                        cycle_count <= cycle_count + 6'd1;
                        next_state <= PROCESS;
                    end
                end

                PROCESS: begin
                    if (current_card == QUEEN || current_card == KING) begin
                        // Discard and switch player
                        active_player <= ~active_player;
                        next_state <= DRAW;
                    end else if (current_card == JACK) begin
                        // Jack logic
                        if (active_player == THETA) begin
                            // Theta: Minimize unfilled slots - fill any unfilled slot
                            integer i;
                            for (i = 0; i < 10; i = i + 1) begin
                                if (slots[i] != FILLED) begin
                                    slots[i] <= FILLED;
                                    break;
                                end
                            end
                        end else begin
                            // Friend: Fill lowest unfilled slot
                            integer slot;
                            slot = find_lowest_unfilled(slots[10:19]);
                            slots[slot + 10] <= FILLED;
                        end
                        next_state <= CHECK_WIN;
                    end else begin
                        // Ace-Ten card
                        reg [3:0] target_slot;
                        target_slot = card_to_slot(current_card);

                        if (active_player == THETA) begin
                            if (slots[target_slot] == FILLED) begin
                                // Discard and switch player
                                active_player <= ~active_player;
                                next_state <= DRAW;
                            end else begin
                                // Uncover face-down card
                                slots[target_slot] <= FILLED;
                                next_state <= CHECK_WIN;
                            end
                        end else begin
                            if (slots[target_slot + 10] == FILLED) begin
                                // Discard and switch player
                                active_player <= ~active_player;
                                next_state <= DRAW;
                            end else begin
                                // Uncover face-down card
                                slots[target_slot + 10] <= FILLED;
                                next_state <= CHECK_WIN;
                            end
                        end
                    end
                end

                CHECK_WIN: begin
                    reg [3:0] theta_filled, friend_filled;
                    theta_filled = count_filled(slots[0:9]);
                    friend_filled = count_filled(slots[10:19]);

                    if (theta_filled == 4'd10) begin
                        theta_win <= 1'b1;
                        friend_win <= 1'b0;
                        next_state <= FINISH;
                    end else if (friend_filled == 4'd10) begin
                        theta_win <= 1'b0;
                        friend_win <= 1'b1;
                        next_state <= FINISH;
                    end else begin
                        // Switch player and continue
                        active_player <= ~active_player;
                        next_state <= DRAW;
                    end
                end

                FINISH: begin
                    if (theta_win) begin
                        result <= 2'd0; // Theta wins
                    end else if (friend_win) begin
                        result <= 2'd1; // Friend wins
                    end else begin
                        result <= 2'd2; // Draw/Error
                    end
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    result <= 2'd3; // Invalid
                end
            endcase
        end
    end

endmodule