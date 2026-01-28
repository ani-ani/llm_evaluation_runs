module bingo_tie_detector(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] arr_0_0, input wire [15:0] arr_0_1, input wire [15:0] arr_0_2, input wire [15:0] arr_0_3, input wire [15:0] arr_0_4,
    input wire [15:0] arr_0_5, input wire [15:0] arr_0_6, input wire [15:0] arr_0_7, input wire [15:0] arr_0_8, input wire [15:0] arr_0_9,
    input wire [15:0] arr_0_10, input wire [15:0] arr_0_11, input wire [15:0] arr_0_12, input wire [15:0] arr_0_13, input wire [15:0] arr_0_14,
    input wire [15:0] arr_0_15, input wire [15:0] arr_0_16, input wire [15:0] arr_0_17, input wire [15:0] arr_0_18, input wire [15:0] arr_0_19,
    input wire [15:0] arr_0_20, input wire [15:0] arr_0_21, input wire [15:0] arr_0_22, input wire [15:0] arr_0_23, input wire [15:0] arr_0_24,
    input wire [15:0] arr_1_0, input wire [15:0] arr_1_1, input wire [15:0] arr_1_2, input wire [15:0] arr_1_3, input wire [15:0] arr_1_4,
    input wire [15:0] arr_1_5, input wire [15:0] arr_1_6, input wire [15:0] arr_1_7, input wire [15:0] arr_1_8, input wire [15:0] arr_1_9,
    input wire [15:0] arr_1_10, input wire [15:0] arr_1_11, input wire [15:0] arr_1_12, input wire [15:0] arr_1_13, input wire [15:0] arr_1_14,
    input wire [15:0] arr_1_15, input wire [15:0] arr_1_16, input wire [15:0] arr_1_17, input wire [15:0] arr_1_18, input wire [15:0] arr_1_19,
    input wire [15:0] arr_1_20, input wire [15:0] arr_1_21, input wire [15:0] arr_1_22, input wire [15:0] arr_1_23, input wire [15:0] arr_1_24,
    output reg [7:0] a,
    output reg [7:0] b,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK_PAIR = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    reg [7:0] card_a_idx;
    reg [7:0] card_b_idx;
    reg [7:0] row_a_idx;
    reg [7:0] row_b_idx;
    reg [7:0] col_a_idx;
    reg [7:0] col_b_idx;

    reg [15:0] card_0 [0:24];
    reg [15:0] card_1 [0:24];

    reg [4:0] row_a_complete [0:4];
    reg [4:0] row_b_complete [0:4];

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            a <= 8'd0;
            b <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            card_a_idx <= 8'd0;
            card_b_idx <= 8'd0;
            row_a_idx <= 8'd0;
            row_b_idx <= 8'd0;
            col_a_idx <= 8'd0;
            col_b_idx <= 8'd0;

            for (i = 0; i < 25; i = i + 1) begin
                card_0[i] <= 16'd0;
                card_1[i] <= 16'd0;
            end

            for (i = 0; i < 5; i = i + 1) begin
                row_a_complete[i] <= 5'd0;
                row_b_complete[i] <= 5'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CHECK_PAIR;
                        card_a_idx <= 8'd0;
                        card_b_idx <= 8'd1;
                        row_a_idx <= 8'd0;
                        row_b_idx <= 8'd0;
                        col_a_idx <= 8'd0;
                        col_b_idx <= 8'd0;

                        card_0[0] <= arr_0_0; card_0[1] <= arr_0_1; card_0[2] <= arr_0_2; card_0[3] <= arr_0_3; card_0[4] <= arr_0_4;
                        card_0[5] <= arr_0_5; card_0[6] <= arr_0_6; card_0[7] <= arr_0_7; card_0[8] <= arr_0_8; card_0[9] <= arr_0_9;
                        card_0[10] <= arr_0_10; card_0[11] <= arr_0_11; card_0[12] <= arr_0_12; card_0[13] <= arr_0_13; card_0[14] <= arr_0_14;
                        card_0[15] <= arr_0_15; card_0[16] <= arr_0_16; card_0[17] <= arr_0_17; card_0[18] <= arr_0_18; card_0[19] <= arr_0_19;
                        card_0[20] <= arr_0_20; card_0[21] <= arr_0_21; card_0[22] <= arr_0_22; card_0[23] <= arr_0_23; card_0[24] <= arr_0_24;

                        card_1[0] <= arr_1_0; card_1[1] <= arr_1_1; card_1[2] <= arr_1_2; card_1[3] <= arr_1_3; card_1[4] <= arr_1_4;
                        card_1[5] <= arr_1_5; card_1[6] <= arr_1_6; card_1[7] <= arr_1_7; card_1[8] <= arr_1_8; card_1[9] <= arr_1_9;
                        card_1[10] <= arr_1_10; card_1[11] <= arr_1_11; card_1[12] <= arr_1_12; card_1[13] <= arr_1_13; card_1[14] <= arr_1_14;
                        card_1[15] <= arr_1_15; card_1[16] <= arr_1_16; card_1[17] <= arr_1_17; card_1[18] <= arr_1_18; card_1[19] <= arr_1_19;
                        card_1[20] <= arr_1_20; card_1[21] <= arr_1_21; card_1[22] <= arr_1_22; card_1[23] <= arr_1_23; card_1[24] <= arr_1_24;

                        for (i = 0; i < 5; i = i + 1) begin
                            row_a_complete[i] <= 5'd0;
                            row_b_complete[i] <= 5'd0;
                        end
                    end
                end

                CHECK_PAIR: begin
                    cycle_count <= cycle_count + 8'd1;

                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        reg [15:0] current_num_a;
                        reg [15:0] current_num_b;
                        reg found_tie;
                        reg [7:0] temp_a;
                        reg [7:0] temp_b;

                        found_tie = 1'b0;

                        if (card_a_idx == 8'd0 && card_b_idx == 8'd1) begin
                            for (row_a_idx = 0; row_a_idx < 5; row_a_idx = row_a_idx + 1) begin
                                for (row_b_idx = 0; row_b_idx < 5; row_b_idx = row_b_idx + 1) begin
                                    for (col_a_idx = 0; col_a_idx < 5; col_a_idx = col_a_idx + 1) begin
                                        for (col_b_idx = 0; col_b_idx < 5; col_b_idx = col_b_idx + 1) begin
                                            current_num_a = card_0[row_a_idx * 5 + col_a_idx];
                                            current_num_b = card_1[row_b_idx * 5 + col_b_idx];

                                            if (current_num_a == current_num_b && current_num_a != 16'd0) begin
                                                row_a_complete[row_a_idx] = row_a_complete[row_a_idx] | (1 << col_a_idx);
                                                row_b_complete[row_b_idx] = row_b_complete[row_b_idx] | (1 << col_b_idx);

                                                if (row_a_complete[row_a_idx] == 5'd31 && row_b_complete[row_b_idx] == 5'd31) begin
                                                    found_tie = 1'b1;
                                                    temp_a = 8'd1;
                                                    temp_b = 8'd2;
                                                end
                                            end
                                        end
                                    end
                                end
                            end

                            if (found_tie) begin
                                a <= temp_a;
                                b <= temp_b;
                                state <= FINISH;
                            end else begin
                                state <= FINISH;
                            end
                        end else begin
                            state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule