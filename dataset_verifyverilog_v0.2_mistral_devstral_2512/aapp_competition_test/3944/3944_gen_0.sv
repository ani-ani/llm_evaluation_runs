`timescale 1ns / 1ps

module card_game_winner (
    input clk,
    input rst_n,
    input start,
    input [2:0] alice_deck_0, alice_deck_1, alice_deck_2, alice_deck_3,
    input [2:0] alice_deck_4, alice_deck_5, alice_deck_6, alice_deck_7,
    input [2:0] bob_deck_0, bob_deck_1, bob_deck_2, bob_deck_3,
    input [2:0] bob_deck_4, bob_deck_5, bob_deck_6, bob_deck_7,
    input [2:0] charlie_deck_0, charlie_deck_1, charlie_deck_2, charlie_deck_3,
    input [2:0] charlie_deck_4, charlie_deck_5, charlie_deck_6, charlie_deck_7,
    input [2:0] len_a,
    input [2:0] len_b,
    input [2:0] len_c,
    output reg result,
    output reg done
);

    localparam PL_A = 2'b00;
    localparam PL_B = 2'b01;
    localparam PL_C = 2'b10;

    localparam IDLE = 3'b000;
    localparam CHECK_TURN = 3'b001;
    localparam DISCARD = 3'b010;
    localparam UPDATE_NEXT = 3'b011;
    localparam FINISH = 3'b100;

    reg [2:0] state;
    reg [2:0] current_player;
    reg [2:0] ptr_a, ptr_b, ptr_c;
    reg [2:0] current_card;
    reg [7:0] cycle_counter;

    wire [2:0] read_card_a, read_card_b, read_card_c;
    assign read_card_a = (ptr_a == 0) ? alice_deck_0 : (ptr_a == 1) ? alice_deck_1 : (ptr_a == 2) ? alice_deck_2 : (ptr_a == 3) ? alice_deck_3 : (ptr_a == 4) ? alice_deck_4 : (ptr_a == 5) ? alice_deck_5 : (ptr_a == 6) ? alice_deck_6 : alice_deck_7;
    assign read_card_b = (ptr_b == 0) ? bob_deck_0 : (ptr_b == 1) ? bob_deck_1 : (ptr_b == 2) ? bob_deck_2 : (ptr_b == 3) ? bob_deck_3 : (ptr_b == 4) ? bob_deck_4 : (ptr_b == 5) ? bob_deck_5 : (ptr_b == 6) ? bob_deck_6 : bob_deck_7;
    assign read_card_c = (ptr_c == 0) ? charlie_deck_0 : (ptr_c == 1) ? charlie_deck_1 : (ptr_c == 2) ? charlie_deck_2 : (ptr_c == 3) ? charlie_deck_3 : (ptr_c == 4) ? charlie_deck_4 : (ptr_c == 5) ? charlie_deck_5 : (ptr_c == 6) ? charlie_deck_6 : charlie_deck_7;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            ptr_a <= 0;
            ptr_b <= 0;
            ptr_c <= 0;
            current_player <= PL_A;
            cycle_counter <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    ptr_a <= 0;
                    ptr_b <= 0;
                    ptr_c <= 0;
                    current_player <= PL_A;
                    cycle_counter <= 0;
                    if (start) state <= CHECK_TURN;
                end

                CHECK_TURN: begin
                    if (current_player == PL_A) begin
                        if (ptr_a >= len_a) begin
                            result <= 1;
                            state <= FINISH;
                        end else begin
                            state <= DISCARD;
                        end
                    end else if (current_player == PL_B) begin
                        if (ptr_b >= len_b) begin
                            result <= 0;
                            state <= FINISH;
                        end else begin
                            state <= DISCARD;
                        end
                    end else if (current_player == PL_C) begin
                        if (ptr_c >= len_c) begin
                            result <= 0;
                            state <= FINISH;
                        end else begin
                            state <= DISCARD;
                        end
                    end
                    if (cycle_counter > 8'd200) begin
                        state <= FINISH;
                        result <= 0;
                    end
                end

                DISCARD: begin
                    cycle_counter <= cycle_counter + 1;
                    if (current_player == PL_A) begin
                        current_card <= read_card_a;
                    end else if (current_player == PL_B) begin
                        current_card <= read_card_b;
                    end else begin
                        current_card <= read_card_c;
                    end
                    state <= UPDATE_NEXT;
                end

                UPDATE_NEXT: begin
                    if (current_player == PL_A) ptr_a <= ptr_a + 1;
                    else if (current_player == PL_B) ptr_b <= ptr_b + 1;
                    else ptr_c <= ptr_c + 1;

                    if (current_card == 3'd0) current_player <= PL_A;
                    else if (current_card == 3'd1) current_player <= PL_B;
                    else current_player <= PL_C;

                    state <= CHECK_TURN;
                end

                FINISH: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule