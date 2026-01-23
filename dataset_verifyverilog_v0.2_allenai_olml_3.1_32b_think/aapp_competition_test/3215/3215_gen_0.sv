module card_shuffle_counter (
    input reg clk,
    input reg rst_n,
    input reg start,
    input reg [3:0] card_in,
    input reg valid,
    output reg [1:0] result,
    output reg done
);

    reg [3:0] card_buffer [7:0];
    reg [3:0] card_count;
    reg [2:0] state;
    reg [1:0] computed_result;

    // Position encoding
    reg [2:0] pos [1:8];

    always @(*) begin
        pos[card_buffer[0]] = 0;
        pos[card_buffer[1]] = 1;
        pos[card_buffer[2]] = 2;
        pos[card_buffer[3]] = 3;
        pos[card_buffer[4]] = 4;
        pos[card_buffer[5]] = 5;
        pos[card_buffer[6]] = 6;
        pos[card_buffer[7]] = 7;
    end

    assign sorted = (pos[1] < pos[2]) && (pos[2] < pos[3]) && (pos[3] < pos[4]) && (pos[4] < pos[5]) && (pos[5] < pos[6]) && (pos[6] < pos[7]) && (pos[7] < pos[8]);

    // One-shuffle conditions
    assign high_k1 = pos[2] < pos[3] && pos[3] < pos[4] && pos[4] < pos[5] && pos[5] < pos[6] && pos[6] < pos[7] && pos[7] < pos[8];
    assign high_k2 = pos[3] < pos[4] && pos[4] < pos[5] && pos[5] < pos[6] && pos[6] < pos[7] && pos[7] < pos[8];
    assign high_k3 = pos[4] < pos[5] && pos[5] < pos[6] && pos[6] < pos[7] && pos[7] < pos[8];
    assign high_k4 = pos[5] < pos[6] && pos[6] < pos[7] && pos[7] < pos[8];
    assign high_k5 = pos[6] < pos[7] && pos[7] < pos[8];
    assign high_k6 = pos[7] < pos[8];
    assign high_k7 = 1'b1;

    assign low_k1 = 1'b1;
    assign low_k2 = pos[1] < pos[2];
    assign low_k3 = (pos[1] < pos[2]) && (pos[2] < pos[3]);
    assign low_k4 = (pos[1] < pos[2]) && (pos[2] < pos[3]) && (pos[3] < pos[4]);
    assign low_k5 = (pos[1] < pos[2]) && (pos[2] < pos[3]) && (pos[3] < pos[4]) && (pos[4] < pos[5]);
    assign low_k6 = (pos[1] < pos[2]) && (pos[2] < pos[3]) && (pos[3] < pos[4]) && (pos[4] < pos[5]) && (pos[5] < pos[6]);
    assign low_k7 = (pos[1] < pos[2]) && (pos[2] < pos[3]) && (pos[3] < pos[4]) && (pos[4] < pos[5]) && (pos[5] < pos[6]) && (pos[6] < pos[7]);

    assign cond_k1 = low_k1 && high_k1;
    assign cond_k2 = low_k2 && high_k2;
    assign cond_k3 = low_k3 && high_k3;
    assign cond_k4 = low_k4 && high_k4;
    assign cond_k5 = low_k5 && high_k5;
    assign cond_k6 = low_k6 && high_k6;
    assign cond_k7 = low_k7 && high_k7;

    assign is_one_shuffle = cond_k1 || cond_k2 || cond_k3 || cond_k4 || cond_k5 || cond_k6 || cond_k7;

    // Two-shuffle condition (dummy)
    assign is_two_shuffle = 1'b0;

    // State machine
    always @(posedge clk) begin
        if (!rst_n) begin
            card_count <= 0;
            state <= 3'd0;
            card_buffer <= 8{4'b0};
            computed_result <= 2'b00;
        end else begin
            case (state)
                3'd0: // IDLE
                    if (start == 1'b1) begin
                        card_count <= 0;
                        state <= 3'd1;
                        card_buffer <= 8{4'b0};
                    end
                end
                3'd1: // COLLECT
                    if (valid == 1'b1) begin
                        card_buffer[card_count] <= card_in;
                        card_count <= card_count + 1;
                    end
                    if (card_count == 8) begin
                        state <= 3'd2;
                    end
                end
                3'd2: // CHECK_0
                    if (sorted) begin
                        computed_result <= 2'b00;
                        state <= 3'd5;
                    end else begin
                        state <= 3'd3;
                    end
                end
                3'd3: // CHECK_1
                    if (is_one_shuffle) begin
                        computed_result <= 2'b01;
                        state <= 3'd5;
                    end else begin
                        state <= 3'd4;
                    end
                end
                3'd4: // CHECK_2
                    if (is_two_shuffle) begin
                        computed_result <= 2'b10;
                        state <= 3'd5;
                    end else begin
                        computed_result <= 2'b11;
                        state <= 3'd5;
                    end
                end
                3'd5: // DONE
                    // Stay in DONE
                endcase
            endcase
        end
    end

    // Output assignments
    assign result = computed_result;
    assign done = (state == 3'd5);

endmodule