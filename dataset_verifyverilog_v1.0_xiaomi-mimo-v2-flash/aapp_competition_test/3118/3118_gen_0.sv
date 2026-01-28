module cycle_length(
    input clk,
    input rst_n,
    input start,
    input [2:0] alice_0,
    input [2:0] alice_1,
    input [2:0] alice_2,
    input [2:0] alice_3,
    input [2:0] alice_4,
    input [2:0] alice_5,
    input [2:0] alice_6,
    input [2:0] alice_7,
    input [2:0] bob_0,
    input [2:0] bob_1,
    input [2:0] bob_2,
    input [2:0] bob_3,
    input [2:0] bob_4,
    input [2:0] bob_5,
    input [2:0] bob_6,
    input [2:0] bob_7,
    input [2:0] num_cards,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] SHUFFLE = 3'd2;
    localparam [2:0] CHECK   = 3'd3;
    localparam [2:0] DONE    = 3'd4;
    localparam [2:0] FAIL    = 3'd5;

    // Constants
    localparam [15:0] MAX_ITER = 16'd65535;
    localparam [2:0] MAX_CARDS = 3'd8;

    // Registers
    reg [2:0] state, next_state;
    reg [15:0] counter;
    reg [2:0] deck [0:7];
    reg [2:0] temp_deck [0:7];
    reg [2:0] i;
    reg [2:0] temp_i;
    reg is_identity;
    reg shuffle_done;
    reg check_done;
    reg [1:0] shuffle_count;

    // Combinational signals
    wire [2:0] alice_map [0:7];
    wire [2:0] bob_map [0:7];
    
    assign alice_map[0] = alice_0;
    assign alice_map[1] = alice_1;
    assign alice_map[2] = alice_2;
    assign alice_map[3] = alice_3;
    assign alice_map[4] = alice_4;
    assign alice_map[5] = alice_5;
    assign alice_map[6] = alice_6;
    assign alice_map[7] = alice_7;
    
    assign bob_map[0] = bob_0;
    assign bob_map[1] = bob_1;
    assign bob_map[2] = bob_2;
    assign bob_map[3] = bob_3;
    assign bob_map[4] = bob_4;
    assign bob_map[5] = bob_5;
    assign bob_map[6] = bob_6;
    assign bob_map[7] = bob_7;

    // Next state logic
    always @(*) begin
        next_state = IDLE;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
                else next_state = IDLE;
            end
            LOAD: next_state = SHUFFLE;
            SHUFFLE: begin
                if (shuffle_done) next_state = CHECK;
                else next_state = SHUFFLE;
            end
            CHECK: begin
                if (check_done) begin
                    if (is_identity) next_state = DONE;
                    else if (counter >= MAX_ITER) next_state = FAIL;
                    else next_state = SHUFFLE;
                end else begin
                    next_state = CHECK;
                end
            end
            DONE: next_state = IDLE;
            FAIL: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            counter <= 16'd0;
            shuffle_count <= 2'd0;
            temp_i <= 3'd0;
            is_identity <= 1'b1;
            shuffle_done <= 1'b0;
            check_done <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                deck[i] <= 3'd0;
                temp_deck[i] <= 3'd0;
            end
        end else begin
            done <= 1'b0;
            shuffle_done <= 1'b0;
            check_done <= 1'b0;
            
            case (state)
                IDLE: begin
                    counter <= 16'd0;
                    shuffle_count <= 2'd0;
                    // Initialize deck to identity for next start
                    for (i = 0; i < 8; i = i + 1) begin
                        deck[i] <= i[2:0];
                    end
                end
                
                LOAD: begin
                    // Ensure deck is identity (already set in IDLE)
                    counter <= 16'd0;
                    shuffle_count <= 2'd0;
                end
                
                SHUFFLE: begin
                    if (shuffle_count == 2'd0) begin
                        // Apply Alice permutation
                        temp_deck[0] <= (0 < num_cards) ? alice_map[deck[0]] : deck[0];
                        temp_deck[1] <= (1 < num_cards) ? alice_map[deck[1]] : deck[1];
                        temp_deck[2] <= (2 < num_cards) ? alice_map[deck[2]] : deck[2];
                        temp_deck[3] <= (3 < num_cards) ? alice_map[deck[3]] : deck[3];
                        temp_deck[4] <= (4 < num_cards) ? alice_map[deck[4]] : deck[4];
                        temp_deck[5] <= (5 < num_cards) ? alice_map[deck[5]] : deck[5];
                        temp_deck[6] <= (6 < num_cards) ? alice_map[deck[6]] : deck[6];
                        temp_deck[7] <= (7 < num_cards) ? alice_map[deck[7]] : deck[7];
                        shuffle_count <= 2'd1;
                    end else if (shuffle_count == 2'd1) begin
                        // Apply Bob permutation to temp_deck
                        deck[0] <= (0 < num_cards) ? bob_map[temp_deck[0]] : temp_deck[0];
                        deck[1] <= (1 < num_cards) ? bob_map[temp_deck[1]] : temp_deck[1];
                        deck[2] <= (2 < num_cards) ? bob_map[temp_deck[2]] : temp_deck[2];
                        deck[3] <= (3 < num_cards) ? bob_map[temp_deck[3]] : temp_deck[3];
                        deck[4] <= (4 < num_cards) ? bob_map[temp_deck[4]] : temp_deck[4];
                        deck[5] <= (5 < num_cards) ? bob_map[temp_deck[5]] : temp_deck[5];
                        deck[6] <= (6 < num_cards) ? bob_map[temp_deck[6]] : temp_deck[6];
                        deck[7] <= (7 < num_cards) ? bob_map[temp_deck[7]] : temp_deck[7];
                        shuffle_count <= 2'd2;
                        counter <= counter + 16'd1;
                    end else begin
                        // Shuffle complete
                        shuffle_count <= 2'd0;
                        shuffle_done <= 1'b1;
                    end
                end
                
                CHECK: begin
                    // Check if deck equals identity
                    temp_i <= temp_i + 3'd1;
                    if (temp_i == 3'd0) begin
                        is_identity <= (deck[0] == 3'd0) && (num_cards > 3'd0);
                    end else if (temp_i == 3'd1) begin
                        is_identity <= is_identity && (deck[1] == 3'd1) && (num_cards > 3'd1);
                    end else if (temp_i == 3'd2) begin
                        is_identity <= is_identity && (deck[2] == 3'd2) && (num_cards > 3'd2);
                    end else if (temp_i == 3'd3) begin
                        is_identity <= is_identity && (deck[3] == 3'd3) && (num_cards > 3'd3);
                    end else if (temp_i == 3'd4) begin
                        is_identity <= is_identity && (deck[4] == 3'd4) && (num_cards > 3'd4);
                    end else if (temp_i == 3'd5) begin
                        is_identity <= is_identity && (deck[5] == 3'd5) && (num_cards > 3'd5);
                    end else if (temp_i == 3'd6) begin
                        is_identity <= is_identity && (deck[6] == 3'd6) && (num_cards > 3'd6);
                    end else if (temp_i == 3'd7) begin
                        is_identity <= is_identity && (deck[7] == 3'd7) && (num_cards > 3'd7);
                        check_done <= 1'b1;
                        temp_i <= 3'd0;
                    end
                end
                
                DONE: begin
                    result <= counter;
                    done <= 1'b1;
                end
                
                FAIL: begin
                    result <= 16'd0;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            state <= next_state;
        end
    end
endmodule