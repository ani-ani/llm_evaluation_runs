module trash_game (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [207:0] deck,
    output reg done,
    output reg winner
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] DEAL          = 4'd1;
    localparam [3:0] TURN_START    = 4'd2;
    localparam [3:0] DRAW          = 4'd3;
    localparam [3:0] CHECK         = 4'd4;
    localparam [3:0] NUMBER_STRATEGY = 4'd5;
    localparam [3:0] JACK_STRATEGY = 4'd6;
    localparam [3:0] FILL_SLOT     = 4'd7;
    localparam [3:0] UNCOVER       = 4'd8;
    localparam [3:0] DISCARD       = 4'd9;
    localparam [3:0] DONE_STATE    = 4'd10;

    // Card values
    localparam [3:0] ACE   = 4'd0;
    localparam [3:0] JACK  = 4'd10;
    localparam [3:0] QUEEN = 4'd11;
    localparam [3:0] KING  = 4'd12;

    // Internal registers
    reg [207:0] deck_reg;
    reg [5:0] deck_ptr;            // 0-51, but starting at 80
    reg [3:0] current_card;
    reg player_turn;               // 0: Theta, 1: Friend
    reg [9:0] theta_filled;        // 10 slots, bit i = slot i filled
    reg [9:0] friend_filled;
    reg [39:0] theta_faceup;       // 10 slots * 4 bits
    reg [39:0] friend_faceup;
    reg [1:0] seen_count [0:12];   // 13 counters, 2 bits each
    reg [3:0] fsm_state;
    reg [3:0] temp_slot;           // slot being filled
    reg [3:0] temp_card;           // for storing card during UNCOVER
    reg [5:0] cycle_count;         // safety counter

    // Memory for deck (52 x 4 bits)
    reg [3:0] deck_memory [0:51];

    // Combinational signals for Theta strategy
    reg [3:0] best_slot_theta;
    reg [1:0] best_remaining;
    reg [1:0] remaining_temp;
    reg [9:0] unfilled_slots;
    reg [3:0] lowest_unfilled_friend;
    reg all_filled_theta;
    reg all_filled_friend;

    integer i;

    // Combinational: compute best slot for Theta
    always @(*) begin
        best_slot_theta = 4'd0;
        best_remaining = 2'd3;
        for (i = 0; i < 10; i = i + 1) begin
            if (~theta_filled[i]) begin
                remaining_temp = 4 - seen_count[i];
                if (remaining_temp < best_remaining) begin
                    best_remaining = remaining_temp;
                    best_slot_theta = i;
                end
            end
        end
    end

    // Combinational: lowest unfilled slot for Friend
    always @(*) begin
        lowest_unfilled_friend = 4'd0;
        for (i = 0; i < 10; i = i + 1) begin
            if (~friend_filled[i]) begin
                lowest_unfilled_friend = i;
            end
        end
    end

    // Combinational: check all filled
    always @(*) begin
        all_filled_theta = (theta_filled == 10'h3FF);
        all_filled_friend = (friend_filled == 10'h3FF);
    end

    // State update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fsm_state <= IDLE;
            done <= 1'b0;
            winner <= 1'b0;
            deck_ptr <= 6'd0;
            current_card <= 4'd0;
            player_turn <= 1'b0;
            theta_filled <= 10'd0;
            friend_filled <= 10'd0;
            theta_faceup <= 40'd0;
            friend_faceup <= 40'd0;
            deck_reg <= 208'd0;
            temp_slot <= 4'd0;
            temp_card <= 4'd0;
            cycle_count <= 6'd0;
            for (i = 0; i < 13; i = i + 1) begin
                seen_count[i] <= 2'd0;
            end
        end else begin
            case (fsm_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        fsm_state <= DEAL;
                    end
                end

                DEAL: begin
                    // Load deck_memory from deck input
                    deck_reg <= deck;
                    for (i = 0; i < 52; i = i + 1) begin
                        deck_memory[i] <= deck[4*i +: 4];
                    end
                    deck_ptr <= 6'd52;  // Start at position 52 (0-11 are friend's, 12-21 are Theta's, 22+ are draw pile)
                    player_turn <= 1'b0;
                    theta_filled <= 10'd0;
                    friend_filled <= 10'd0;
                    theta_faceup <= 40'd0;
                    friend_faceup <= 40'd0;
                    for (i = 0; i < 13; i = i + 1) begin
                        seen_count[i] <= 2'd0;
                    end
                    fsm_state <= TURN_START;
                end

                TURN_START: begin
                    cycle_count <= 6'd0;
                    fsm_state <= DRAW;
                end

                DRAW: begin
                    current_card <= deck_memory[deck_ptr];
                    deck_ptr <= deck_ptr + 6'd1;
                    fsm_state <= CHECK;
                end

                CHECK: begin
                    if (current_card == JACK)
                        fsm_state <= JACK_STRATEGY;
                    else if (current_card <= 9)
                        fsm_state <= NUMBER_STRATEGY;
                    else
                        fsm_state <= DISCARD;
                end

                NUMBER_STRATEGY: begin
                    if (player_turn == 1'b0) begin  // Theta
                        if (~theta_filled[current_card]) begin
                            temp_slot <= current_card;
                            fsm_state <= FILL_SLOT;
                        end else begin
                            fsm_state <= DISCARD;
                        end
                    end else begin  // Friend
                        if (~friend_filled[current_card]) begin
                            temp_slot <= current_card;
                            fsm_state <= FILL_SLOT;
                        end else begin
                            fsm_state <= DISCARD;
                        end
                    end
                end

                JACK_STRATEGY: begin
                    if (player_turn == 1'b0) begin
                        temp_slot <= best_slot_theta;
                    end else begin
                        temp_slot <= lowest_unfilled_friend;
                    end
                    fsm_state <= FILL_SLOT;
                end

                FILL_SLOT: begin
                    if (player_turn == 1'b0) begin  // Theta
                        theta_filled[temp_slot] <= 1'b1;
                        theta_faceup[4*temp_slot +: 4] <= current_card;
                        seen_count[current_card] <= seen_count[current_card] + 2'd1;
                        if (all_filled_theta) begin
                            done <= 1'b1;
                            winner <= 1'b1;
                            fsm_state <= DONE_STATE;
                        end else begin
                            fsm_state <= UNCOVER;
                        end
                    end else begin  // Friend
                        friend_filled[temp_slot] <= 1'b1;
                        friend_faceup[4*temp_slot +: 4] <= current_card;
                        seen_count[current_card] <= seen_count[current_card] + 2'd1;
                        if (all_filled_friend) begin
                            done <= 1'b1;
                            winner <= 1'b0;
                            fsm_state <= DONE_STATE;
                        end else begin
                            fsm_state <= UNCOVER;
                        end
                    end
                end

                UNCOVER: begin
                    if (player_turn == 1'b0) begin
                        // Theta's face-down: position 10 + temp_slot
                        temp_card <= deck_memory[10 + temp_slot];
                    end else begin
                        // Friend's face-down: position 0 + temp_slot
                        temp_card <= deck_memory[temp_slot];
                    end
                    fsm_state <= CHECK;
                end

                DISCARD: begin
                    if (current_card <= 12) begin
                        seen_count[current_card] <= seen_count[current_card] + 2'd1;
                    end
                    player_turn <= ~player_turn;
                    cycle_count <= cycle_count + 6'd1;
                    if (cycle_count >= 6'd50) begin
                        done <= 1'b1;
                        winner <= 1'b0;  // No winner if timeout
                        fsm_state <= DONE_STATE;
                    end else begin
                        fsm_state <= TURN_START;
                    end
                end

                DONE_STATE: begin
                    fsm_state <= DONE_STATE;
                end

                default: fsm_state <= IDLE;
            endcase
        end
    end

endmodule