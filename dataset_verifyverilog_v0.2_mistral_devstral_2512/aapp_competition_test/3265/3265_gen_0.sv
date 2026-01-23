module vacation_planner(
    input clk,
    input rst_n,
    input start,
    input [2:0] N,
    input [7:0] L,
    input [7:0] adj_matrix_0_0, adj_matrix_0_1, adj_matrix_0_2, adj_matrix_0_3, adj_matrix_0_4, adj_matrix_0_5, adj_matrix_0_6, adj_matrix_0_7,
    input [7:0] adj_matrix_1_0, adj_matrix_1_1, adj_matrix_1_2, adj_matrix_1_3, adj_matrix_1_4, adj_matrix_1_5, adj_matrix_1_6, adj_matrix_1_7,
    input [7:0] adj_matrix_2_0, adj_matrix_2_1, adj_matrix_2_2, adj_matrix_2_3, adj_matrix_2_4, adj_matrix_2_5, adj_matrix_2_6, adj_matrix_2_7,
    input [7:0] adj_matrix_3_0, adj_matrix_3_1, adj_matrix_3_2, adj_matrix_3_3, adj_matrix_3_4, adj_matrix_3_5, adj_matrix_3_6, adj_matrix_3_7,
    input [7:0] adj_matrix_4_0, adj_matrix_4_1, adj_matrix_4_2, adj_matrix_4_3, adj_matrix_4_4, adj_matrix_4_5, adj_matrix_4_6, adj_matrix_4_7,
    input [7:0] adj_matrix_5_0, adj_matrix_5_1, adj_matrix_5_2, adj_matrix_5_3, adj_matrix_5_4, adj_matrix_5_5, adj_matrix_5_6, adj_matrix_5_7,
    input [7:0] adj_matrix_6_0, adj_matrix_6_1, adj_matrix_6_2, adj_matrix_6_3, adj_matrix_6_4, adj_matrix_6_5, adj_matrix_6_6, adj_matrix_6_7,
    input [7:0] adj_matrix_7_0, adj_matrix_7_1, adj_matrix_7_2, adj_matrix_7_3, adj_matrix_7_4, adj_matrix_7_5, adj_matrix_7_6, adj_matrix_7_7,
    output reg [7:0] result,
    output reg done
);

    // Parameters
    localparam IDLE = 3'b000;
    localparam PRECOMPUTE = 3'b001;
    localparam SIMULATE = 3'b010;
    localparam CHECK = 3'b011;
    localparam DONE = 3'b100;

    // State machine
    reg [2:0] state = IDLE;

    // Transition matrix (8x8, 32-bit Q16.16)
    reg [31:0] trans_matrix [0:7][0:7];

    // State vector (8 nodes, 32-bit)
    reg [31:0] state_vec [0:7];

    // Counters
    reg [7:0] day_counter = 0;
    reg [2:0] row_counter = 0;
    reg [2:0] col_counter = 0;
    reg [31:0] row_sum = 0;

    // Temporary registers
    reg [31:0] temp_product = 0;
    reg [31:0] temp_sum = 0;

    // Constants
    localparam [31:0] SCALE = 32'd10000;
    localparam [31:0] TARGET = 32'd9500;

    // Reset logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd255;
            day_counter <= 8'd0;
            row_counter <= 3'd0;
            col_counter <= 3'd0;
            row_sum <= 32'd0;
            temp_product <= 32'd0;
            temp_sum <= 32'd0;
            for (int i = 0; i < 8; i = i + 1) begin
                for (int j = 0; j < 8; j = j + 1) begin
                    trans_matrix[i][j] <= 32'd0;
                end
                state_vec[i] <= 32'd0;
            end
            state_vec[0] <= 32'd10000; // Initial state at node 0
        end
    end

    // State machine logic
    always @(posedge clk) begin
        if (!rst_n) begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PRECOMPUTE;
                        done <= 1'b0;
                        result <= 8'd255;
                        day_counter <= L;
                        row_counter <= 3'd0;
                        col_counter <= 3'd0;
                        row_sum <= 32'd0;
                    end
                end

                PRECOMPUTE: begin
                    // Calculate row sum
                    if (col_counter < N) begin
                        case (row_counter)
                            0: row_sum <= row_sum + adj_matrix_0_0 + adj_matrix_0_1 + adj_matrix_0_2 + adj_matrix_0_3 + adj_matrix_0_4 + adj_matrix_0_5 + adj_matrix_0_6 + adj_matrix_0_7;
                            1: row_sum <= row_sum + adj_matrix_1_0 + adj_matrix_1_1 + adj_matrix_1_2 + adj_matrix_1_3 + adj_matrix_1_4 + adj_matrix_1_5 + adj_matrix_1_6 + adj_matrix_1_7;
                            2: row_sum <= row_sum + adj_matrix_2_0 + adj_matrix_2_1 + adj_matrix_2_2 + adj_matrix_2_3 + adj_matrix_2_4 + adj_matrix_2_5 + adj_matrix_2_6 + adj_matrix_2_7;
                            3: row_sum <= row_sum + adj_matrix_3_0 + adj_matrix_3_1 + adj_matrix_3_2 + adj_matrix_3_3 + adj_matrix_3_4 + adj_matrix_3_5 + adj_matrix_3_6 + adj_matrix_3_7;
                            4: row_sum <= row_sum + adj_matrix_4_0 + adj_matrix_4_1 + adj_matrix_4_2 + adj_matrix_4_3 + adj_matrix_4_4 + adj_matrix_4_5 + adj_matrix_4_6 + adj_matrix_4_7;
                            5: row_sum <= row_sum + adj_matrix_5_0 + adj_matrix_5_1 + adj_matrix_5_2 + adj_matrix_5_3 + adj_matrix_5_4 + adj_matrix_5_5 + adj_matrix_5_6 + adj_matrix_5_7;
                            6: row_sum <= row_sum + adj_matrix_6_0 + adj_matrix_6_1 + adj_matrix_6_2 + adj_matrix_6_3 + adj_matrix_6_4 + adj_matrix_6_5 + adj_matrix_6_6 + adj_matrix_6_7;
                            7: row_sum <= row_sum + adj_matrix_7_0 + adj_matrix_7_1 + adj_matrix_7_2 + adj_matrix_7_3 + adj_matrix_7_4 + adj_matrix_7_5 + adj_matrix_7_6 + adj_matrix_7_7;
                        endcase
                        col_counter <= col_counter + 1'b1;
                    end else begin
                        // Compute transition probabilities
                        if (row_counter < N) begin
                            case (row_counter)
                                0: begin
                                    if (row_sum != 0) begin
                                        trans_matrix[0][0] <= (adj_matrix_0_0 * SCALE) / row_sum;
                                        trans_matrix[0][1] <= (adj_matrix_0_1 * SCALE) / row_sum;
                                        trans_matrix[0][2] <= (adj_matrix_0_2 * SCALE) / row_sum;
                                        trans_matrix[0][3] <= (adj_matrix_0_3 * SCALE) / row_sum;
                                        trans_matrix[0][4] <= (adj_matrix_0_4 * SCALE) / row_sum;
                                        trans_matrix[0][5] <= (adj_matrix_0_5 * SCALE) / row_sum;
                                        trans_matrix[0][6] <= (adj_matrix_0_6 * SCALE) / row_sum;
                                        trans_matrix[0][7] <= (adj_matrix_0_7 * SCALE) / row_sum;
                                    end
                                end
                                1: begin
                                    if (row_sum != 0) begin
                                        trans_matrix[1][0] <= (adj_matrix_1_0 * SCALE) / row_sum;
                                        trans_matrix[1][1] <= (adj_matrix_1_1 * SCALE) / row_sum;
                                        trans_matrix[1][2] <= (adj_matrix_1_2 * SCALE) / row_sum;
                                        trans_matrix[1][3] <= (adj_matrix_1_3 * SCALE) / row_sum;
                                        trans_matrix[1][4] <= (adj_matrix_1_4 * SCALE) / row_sum;
                                        trans_matrix[1][5] <= (adj_matrix_1_5 * SCALE) / row_sum;
                                        trans_matrix[1][6] <= (adj_matrix_1_6 * SCALE) / row_sum;
                                        trans_matrix[1][7] <= (adj_matrix_1_7 * SCALE) / row_sum;
                                    end
                                end
                                2: begin
                                    if (row_sum != 0) begin
                                        trans_matrix[2][0] <= (adj_matrix_2_0 * SCALE) / row_sum;
                                        trans_matrix[2][1] <= (adj_matrix_2_1 * SCALE) / row_sum;
                                        trans_matrix[2][2] <= (adj_matrix_2_2 * SCALE) / row_sum;
                                        trans_matrix[2][3] <= (adj_matrix_2_3 * SCALE) / row_sum;
                                        trans_matrix[2][4] <= (adj_matrix_2_4 * SCALE) / row_sum;
                                        trans_matrix[2][5] <= (adj_matrix_2_5 * SCALE) / row_sum;
                                        trans_matrix[2][6] <= (adj_matrix_2_6 * SCALE) / row_sum;
                                        trans_matrix[2][7] <= (adj_matrix_2_7 * SCALE) / row_sum;
                                    end
                                end
                                3: begin
                                    if (row_sum != 0) begin
                                        trans_matrix[3][0] <= (adj_matrix_3_0 * SCALE) / row_sum;
                                        trans_matrix[3][1] <= (adj_matrix_3_1 * SCALE) / row_sum;
                                        trans_matrix[3][2] <= (adj_matrix_3_2 * SCALE) / row_sum;
                                        trans_matrix[3][3] <= (adj_matrix_3_3 * SCALE) / row_sum;
                                        trans_matrix[3][4] <= (adj_matrix_3_4 * SCALE) / row_sum;
                                        trans_matrix[3][5] <= (adj_matrix_3_5 * SCALE) / row_sum;
                                        trans_matrix[3][6] <= (adj_matrix_3_6 * SCALE) / row_sum;
                                        trans_matrix[3][7] <= (adj_matrix_3_7 * SCALE) / row_sum;
                                    end
                                end
                                4: begin
                                    if (row_sum != 0) begin
                                        trans_matrix[4][0] <= (adj_matrix_4_0 * SCALE) / row_sum;
                                        trans_matrix[4][1] <= (adj_matrix_4_1 * SCALE) / row_sum;
                                        trans_matrix[4][2] <= (adj_matrix_4_2 * SCALE) / row_sum;
                                        trans_matrix[4][3] <= (adj_matrix_4_3 * SCALE) / row_sum;
                                        trans_matrix[4][4] <= (adj_matrix_4_4 * SCALE) / row_sum;
                                        trans_matrix[4][5] <= (adj_matrix_4_5 * SCALE) / row_sum;
                                        trans_matrix[4][6] <= (adj_matrix_4_6 * SCALE) / row_sum;
                                        trans_matrix[4][7] <= (adj_matrix_4_7 * SCALE) / row_sum;
                                    end
                                end
                                5: begin
                                    if (row_sum != 0) begin
                                        trans_matrix[5][0] <= (adj_matrix_5_0 * SCALE) / row_sum;
                                        trans_matrix[5][1] <= (adj_matrix_5_1 * SCALE) / row_sum;
                                        trans_matrix[5][2] <= (adj_matrix_5_2 * SCALE) / row_sum;
                                        trans_matrix[5][3] <= (adj_matrix_5_3 * SCALE) / row_sum;
                                        trans_matrix[5][4] <= (adj_matrix_5_4 * SCALE) / row_sum;
                                        trans_matrix[5][5] <= (adj_matrix_5_5 * SCALE) / row_sum;
                                        trans_matrix[5][6] <= (adj_matrix_5_6 * SCALE) / row_sum;
                                        trans_matrix[5][7] <= (adj_matrix_5_7 * SCALE) / row_sum;
                                    end
                                end
                                6: begin
                                    if (row_sum != 0) begin
                                        trans_matrix[6][0] <= (adj_matrix_6_0 * SCALE) / row_sum;
                                        trans_matrix[6][1] <= (adj_matrix_6_1 * SCALE) / row_sum;
                                        trans_matrix[6][2] <= (adj_matrix_6_2 * SCALE) / row_sum;
                                        trans_matrix[6][3] <= (adj_matrix_6_3 * SCALE) / row_sum;
                                        trans_matrix[6][4] <= (adj_matrix_6_4 * SCALE) / row_sum;
                                        trans_matrix[6][5] <= (adj_matrix_6_5 * SCALE) / row_sum;
                                        trans_matrix[6][6] <= (adj_matrix_6_6 * SCALE) / row_sum;
                                        trans_matrix[6][7] <= (adj_matrix_6_7 * SCALE) / row_sum;
                                    end
                                end
                                7: begin
                                    if (row_sum != 0) begin
                                        trans_matrix[7][0] <= (adj_matrix_7_0 * SCALE) / row_sum;
                                        trans_matrix[7][1] <= (adj_matrix_7_1 * SCALE) / row_sum;
                                        trans_matrix[7][2] <= (adj_matrix_7_2 * SCALE) / row_sum;
                                        trans_matrix[7][3] <= (adj_matrix_7_3 * SCALE) / row_sum;
                                        trans_matrix[7][4] <= (adj_matrix_7_4 * SCALE) / row_sum;
                                        trans_matrix[7][5] <= (adj_matrix_7_5 * SCALE) / row_sum;
                                        trans_matrix[7][6] <= (adj_matrix_7_6 * SCALE) / row_sum;
                                        trans_matrix[7][7] <= (adj_matrix_7_7 * SCALE) / row_sum;
                                    end
                                end
                            endcase
                            row_counter <= row_counter + 1'b1;
                            col_counter <= 3'd0;
                            row_sum <= 32'd0;
                        end else begin
                            state <= SIMULATE;
                            row_counter <= 3'd0;
                            col_counter <= 3'd0;
                        end
                    end
                end

                SIMULATE: begin
                    // Update state vector
                    if (col_counter < N) begin
                        temp_sum <= 32'd0;
                        for (int i = 0; i < N; i = i + 1) begin
                            temp_product <= state_vec[i] * trans_matrix[i][col_counter];
                            temp_sum <= temp_sum + (temp_product / SCALE);
                        end
                        state_vec[col_counter] <= temp_sum;
                        col_counter <= col_counter + 1'b1;
                    end else begin
                        state <= CHECK;
                        col_counter <= 3'd0;
                    end
                end

                CHECK: begin
                    // Check if state[N-1] == 9500
                    if (state_vec[N-1] == TARGET && day_counter >= L) begin
                        result <= day_counter;
                        state <= DONE;
                    end else begin
                        // Increment day counter
                        day_counter <= day_counter + 1'b1;
                        if (day_counter > L + 9) begin
                            result <= 8'd255;
                            state <= DONE;
                        end else begin
                            state <= SIMULATE;
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule