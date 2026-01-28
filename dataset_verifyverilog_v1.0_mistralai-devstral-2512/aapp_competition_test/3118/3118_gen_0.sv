module ShuffleCycleCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] alice_0,
    input wire [2:0] alice_1,
    input wire [2:0] alice_2,
    input wire [2:0] alice_3,
    input wire [2:0] alice_4,
    input wire [2:0] alice_5,
    input wire [2:0] alice_6,
    input wire [2:0] alice_7,
    input wire [2:0] bob_0,
    input wire [2:0] bob_1,
    input wire [2:0] bob_2,
    input wire [2:0] bob_3,
    input wire [2:0] bob_4,
    input wire [2:0] bob_5,
    input wire [2:0] bob_6,
    input wire [2:0] bob_7,
    input wire [2:0] num_cards,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] SHUFFLE = 3'd2;
    localparam [2:0] CHECK   = 3'd3;
    localparam [2:0] DONE    = 3'd4;

    reg [2:0] state, next_state;
    reg [15:0] iteration_counter;
    reg [2:0] deck [0:7];
    reg [2:0] temp_deck [0:7];
    reg [2:0] identity [0:7];
    reg [2:0] max_cards;
    reg deck_identity;
    integer i;

    // Initialize identity deck
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            iteration_counter <= 16'd0;
            for (i = 0; i < 8; i = i + 1) begin
                deck[i] <= 3'd0;
                temp_deck[i] <= 3'd0;
                identity[i] <= i;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        deck_identity = 1'b1;
        for (i = 0; i < 8; i = i + 1) begin
            if (deck[i] != identity[i]) begin
                deck_identity = 1'b0;
            end
        end

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end

            LOAD: begin
                max_cards = num_cards;
                for (i = 0; i < 8; i = i + 1) begin
                    if (i < max_cards) begin
                        deck[i] = identity[i];
                    end else begin
                        deck[i] = 3'd0;
                    end
                end
                iteration_counter = 16'd0;
                next_state = SHUFFLE;
            end

            SHUFFLE: begin
                // Apply Alice permutation
                for (i = 0; i < 8; i = i + 1) begin
                    if (i < max_cards) begin
                        case (i)
                            3'd0: temp_deck[i] = deck[alice_0];
                            3'd1: temp_deck[i] = deck[alice_1];
                            3'd2: temp_deck[i] = deck[alice_2];
                            3'd3: temp_deck[i] = deck[alice_3];
                            3'd4: temp_deck[i] = deck[alice_4];
                            3'd5: temp_deck[i] = deck[alice_5];
                            3'd6: temp_deck[i] = deck[alice_6];
                            3'd7: temp_deck[i] = deck[alice_7];
                            default: temp_deck[i] = 3'd0;
                        endcase
                    end else begin
                        temp_deck[i] = 3'd0;
                    end
                end
                
                // Apply Bob permutation
                for (i = 0; i < 8; i = i + 1) begin
                    if (i < max_cards) begin
                        case (i)
                            3'd0: deck[i] = temp_deck[bob_0];
                            3'd1: deck[i] = temp_deck[bob_1];
                            3'd2: deck[i] = temp_deck[bob_2];
                            3'd3: deck[i] = temp_deck[bob_3];
                            3'd4: deck[i] = temp_deck[bob_4];
                            3'd5: deck[i] = temp_deck[bob_5];
                            3'd6: deck[i] = temp_deck[bob_6];
                            3'd7: deck[i] = temp_deck[bob_7];
                            default: deck[i] = 3'd0;
                        endcase
                    end else begin
                        deck[i] = 3'd0;
                    end
                end
                
                iteration_counter = iteration_counter + 16'd1;
                next_state = CHECK;
            end

            CHECK: begin
                if (deck_identity || iteration_counter >= 16'd65535) begin
                    if (iteration_counter >= 16'd65535) begin
                        result = 16'd0;
                    end else begin
                        result = iteration_counter;
                    end
                    next_state = DONE;
                end else begin
                    next_state = SHUFFLE;
                end
            end

            DONE: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Output done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            if (state == DONE) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule