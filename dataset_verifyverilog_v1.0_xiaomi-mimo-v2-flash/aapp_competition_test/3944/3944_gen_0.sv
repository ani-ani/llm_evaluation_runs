module card_game_three(
    input clk,
    input rst_n,
    input start,
    input [3:0] n_val,
    input [3:0] m_val,
    input [3:0] k_val,
    input [15:0] card_a,
    input [15:0] card_b,
    input [15:0] card_c,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] INIT_CONFIG   = 3'd1;
    localparam [2:0] SIMULATE_GAME = 3'd2;
    localparam [2:0] CHECK_WIN     = 3'd3;
    localparam [2:0] NEXT_CONFIG   = 3'd4;
    localparam [2:0] FINISH        = 3'd5;

    // Player constants
    localparam [1:0] ALICE = 2'd0;
    localparam [1:0] BOB   = 2'd1;
    localparam [1:0] CHARLIE = 2'd2;

    // Modulus constant
    localparam [31:0] MOD = 32'd1000000007;

    // State machine registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] cycle_count;  // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd50;

    // Configuration registers
    reg [4:0] n_reg, m_reg, k_reg;  // 5 bits to hold 16+1
    reg [4:0] a_idx, b_idx, c_idx;  // 5 bits for indices (0-16)
    reg [4:0] a_idx_next, b_idx_next, c_idx_next;
    reg [1:0] current_player;
    reg [1:0] current_player_next;
    reg game_active;
    reg game_active_next;

    // Tracking registers
    reg [4:0] total_cards;  // N + M + K
    reg [4:0] cards_played;
    reg [4:0] cards_played_next;

    // Counter for valid configurations
    reg [31:0] counter;
    reg [31:0] counter_next;

    // Winner flag
    reg winner_flag;
    reg winner_flag_next;

    // Temporary calculation registers
    reg [31:0] add_temp;

    // Card value storage
    reg [1:0] card_value;

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INIT_CONFIG;
            end

            INIT_CONFIG: begin
                next_state = SIMULATE_GAME;
            end

            SIMULATE_GAME: begin
                next_state = CHECK_WIN;
            end

            CHECK_WIN: begin
                if (game_active) begin
                    next_state = SIMULATE_GAME;
                end else begin
                    next_state = NEXT_CONFIG;
                end
            end

            NEXT_CONFIG: begin
                if ((a_idx == n_reg) && (b_idx == m_reg) && (c_idx == k_reg)) begin
                    next_state = FINISH;
                end else begin
                    next_state = INIT_CONFIG;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            counter <= 32'd0;
            n_reg <= 5'd0;
            m_reg <= 5'd0;
            k_reg <= 5'd0;
            a_idx <= 5'd0;
            b_idx <= 5'd0;
            c_idx <= 5'd0;
            current_player <= ALICE;
            game_active <= 1'b0;
            cards_played <= 5'd0;
            winner_flag <= 1'b0;
            total_cards <= 5'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 32'd0;
                    cycle_count <= 8'd0;
                    a_idx <= 5'd0;
                    b_idx <= 5'd0;
                    c_idx <= 5'd0;
                    n_reg <= {1'b0, n_val};
                    m_reg <= {1'b0, m_val};
                    k_reg <= {1'b0, k_val};
                    total_cards <= {1'b0, n_val} + {1'b0, m_val} + {1'b0, k_val};
                end

                INIT_CONFIG: begin
                    // Initialize game simulation
                    current_player <= ALICE;
                    game_active <= 1'b1;
                    cards_played <= 5'd0;
                    winner_flag <= 1'b0;
                    cycle_count <= 8'd0;
                end

                SIMULATE_GAME: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've exceeded max cycles
                    if (cycle_count >= MAX_CYCLES) begin
                        game_active <= 1'b0;
                    end else if (cards_played >= total_cards) begin
                        game_active <= 1'b0;
                    end else begin
                        // Get card value based on current player
                        case (current_player)
                            ALICE: begin
                                card_value <= {card_a[a_idx*2 + 1], card_a[a_idx*2]};
                            end
                            BOB: begin
                                card_value <= {card_b[b_idx*2 + 1], card_b[b_idx*2]};
                            end
                            CHARLIE: begin
                                card_value <= {card_c[c_idx*2 + 1], card_c[c_idx*2]};
                            end
                            default: card_value <= 2'd0;
                        endcase
                    end
                end

                CHECK_WIN: begin
                    if (cycle_count < MAX_CYCLES && cards_played < total_cards) begin
                        // Update indices and check for win
                        case (current_player)
                            ALICE: begin
                                a_idx <= a_idx + 5'd1;
                                if (card_value == 2'd0) current_player <= ALICE;
                                else if (card_value == 2'd1) current_player <= BOB;
                                else current_player <= CHARLIE;
                            end
                            BOB: begin
                                b_idx <= b_idx + 5'd1;
                                if (card_value == 2'd0) current_player <= ALICE;
                                else if (card_value == 2'd1) current_player <= BOB;
                                else current_player <= CHARLIE;
                            end
                            CHARLIE: begin
                                c_idx <= c_idx + 5'd1;
                                if (card_value == 2'd0) current_player <= ALICE;
                                else if (card_value == 2'd1) current_player <= BOB;
                                else current_player <= CHARLIE;
                            end
                        endcase
                        cards_played <= cards_played + 5'd1;
                        
                        // Check for win condition
                        if (a_idx == n_reg && card_value == 2'd1) begin
                            winner_flag <= 1'b1;
                            game_active <= 1'b0;
                        end else if (a_idx == n_reg && card_value == 2'd2) begin
                            game_active <= 1'b0;
                        end else if (b_idx == m_reg && card_value == 2'd0) begin
                            game_active <= 1'b0;
                        end else if (b_idx == m_reg && card_value == 2'd2) begin
                            winner_flag <= 1'b1;
                            game_active <= 1'b0;
                        end else if (c_idx == k_reg && card_value == 2'd0) begin
                            winner_flag <= 1'b1;
                            game_active <= 1'b0;
                        end else if (c_idx == k_reg && card_value == 2'd1) begin
                            game_active <= 1'b0;
                        end
                    end
                end

                NEXT_CONFIG: begin
                    // Increment configuration
                    if (a_idx < n_reg) begin
                        a_idx <= a_idx + 5'd1;
                    end else if (b_idx < m_reg) begin
                        b_idx <= 5'd0;
                        b_idx <= b_idx + 5'd1;
                    end else if (c_idx < k_reg) begin
                        b_idx <= 5'd0;
                        c_idx <= c_idx + 5'd1;
                    end

                    // Add to counter if winner
                    if (winner_flag) begin
                        add_temp = counter + 32'd1;
                        if (add_temp >= MOD) begin
                            counter <= add_temp - MOD;
                        end else begin
                            counter <= add_temp;
                        end
                    end
                end

                FINISH: begin
                    result <= counter;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule