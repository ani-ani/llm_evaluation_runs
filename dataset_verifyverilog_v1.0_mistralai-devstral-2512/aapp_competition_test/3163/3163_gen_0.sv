module BookLiftsCalculator(
    input [3:0] N,
    input [3:0] M,
    input [7:0] init_arr_0 [0:15],
    input [7:0] init_arr_1 [0:15],
    input [7:0] init_arr_2 [0:15],
    input [7:0] init_arr_3 [0:15],
    input [7:0] init_arr_4 [0:15],
    input [7:0] init_arr_5 [0:15],
    input [7:0] init_arr_6 [0:15],
    input [7:0] init_arr_7 [0:15],
    input [7:0] init_arr_8 [0:15],
    input [7:0] init_arr_9 [0:15],
    input [7:0] init_arr_10 [0:15],
    input [7:0] init_arr_11 [0:15],
    input [7:0] init_arr_12 [0:15],
    input [7:0] init_arr_13 [0:15],
    input [7:0] init_arr_14 [0:15],
    input [7:0] init_arr_15 [0:15],
    input [7:0] target_arr_0 [0:15],
    input [7:0] target_arr_1 [0:15],
    input [7:0] target_arr_2 [0:15],
    input [7:0] target_arr_3 [0:15],
    input [7:0] target_arr_4 [0:15],
    input [7:0] target_arr_5 [0:15],
    input [7:0] target_arr_6 [0:15],
    input [7:0] target_arr_7 [0:15],
    input [7:0] target_arr_8 [0:15],
    input [7:0] target_arr_9 [0:15],
    input [7:0] target_arr_10 [0:15],
    input [7:0] target_arr_11 [0:15],
    input [7:0] target_arr_12 [0:15],
    input [7:0] target_arr_13 [0:15],
    input [7:0] target_arr_14 [0:15],
    input [7:0] target_arr_15 [0:15],
    output reg [7:0] lifts,
    output reg error
);

    reg [7:0] total_books;
    reg [7:0] correct_books;
    reg [7:0] init_book_count [0:255];
    reg [7:0] target_book_count [0:255];
    integer i, j, k;

    always @(*) begin
        total_books = 8'd0;
        correct_books = 8'd0;

        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                if (i < N && j < M) begin
                    if (i == 0) begin
                        if (init_arr_0[j] != 8'd0) begin
                            total_books = total_books + 8'd1;
                            if (init_arr_0[j] == target_arr_0[j]) begin
                                correct_books = correct_books + 8'd1;
                            end
                        end
                    end else if (i == 1) begin
                        if (init_arr_1[j] != 8'd0) begin
                            total_books = total_books + 8'd1;
                            if (init_arr_1[j] == target_arr_1[j]) begin
                                correct_books = correct_books + 8'd1;
                            end
                        end
                    end else if (i == 2) begin
                        if (init_arr_2[j] != 8'd0) begin
                            total_books = total_books + 8'd1;
                            if (init_arr_2[j] == target_arr_2[j]) begin
                                correct_books = correct_books + 8'd1;
                            end
                        end
                    end else if (i == 3) begin
                        if (init_arr_3[j] != 8'd0) begin
                            total_books = total_books + 8'd1;
                            if (init_arr_3[j] == target_arr_3[j]) begin
                                correct_books = correct_books + 8'd1;
                            end
                        end
                    end else if (i == 4) begin
                        if (init_arr_4[j] != 8'd0) begin
                            total_books = total_books + 8'd1;
                            if (init_arr_4[j] == target_arr_4[j]) begin
                                correct_books = correct_books + 8'd1;
                            end
                        end
                    end else if (i == 5) begin
                        if (init_arr_5[j] != 8'd0) begin
                            total_books = total_books + 8'd1;
                            if (init_arr_5[j] == target_arr_5[j]) begin
                                correct_books = correct_books + 8'd1;
                            end
                        end
                    end else if (i == 6) begin
                        if (init_arr_6[j] != 8'd0) begin
                            total_books = total_books + 8'd1;
                            if (init_arr_6[j] == target_arr_6[j]) begin
                                correct_books = correct_books + 8'd1;
                            end
                        end
                    end else if (i == 7) begin
                        if (init_arr_7[j] != 8'd0) begin
                            total_books = total_books + 8'd1;
                            if (init_arr_7[j] == target_arr_7[j]) begin
                                correct_books = correct_books + 8'd1;
                            end
                        end
                    end else if (i == 8) begin
                        if (init_arr_8[j] != 8'd0) begin
                            total_books = total_books + 8'd1;
                            if (init_arr_8[j] == target_arr_8[j]) begin
                                correct_books = correct_books + 8'd1;
                            end
                        end
                    end else if (i == 9) begin
                        if (init_arr_9[j] != 8'd0) begin
                            total_books = total_books + 8'd1;
                            if (init_arr_9[j] == target_arr_9[j]) begin
                                correct_books = correct_books + 8'd1;
                            end
                        end
                    end else if (i == 10) begin
                        if (init_arr_10[j] != 8'd0) begin
                            total_books = total_books + 8'd1;
                            if (init_arr_10[j] == target_arr_10[j]) begin
                                correct_books = correct_books + 8'd1;
                            end
                        end
                    end else if (i == 11) begin
                        if (init_arr_11[j] != 8'd0) begin
                            total_books = total_books + 8'd1;
                            if (init_arr_11[j] == target_arr_11[j]) begin
                                correct_books = correct_books + 8'd1;
                            end
                        end
                    end else if (i == 12) begin
                        if (init_arr_12[j] != 8'd0) begin
                            total_books = total_books + 8'd1;
                            if (init_arr_12[j] == target_arr_12[j]) begin
                                correct_books = correct_books + 8'd1;
                            end
                        end
                    end else if (i == 13) begin
                        if (init_arr_13[j] != 8'd0) begin
                            total_books = total_books + 8'd1;
                            if (init_arr_13[j] == target_arr_13[j]) begin
                                correct_books = correct_books + 8'd1;
                            end
                        end
                    end else if (i == 14) begin
                        if (init_arr_14[j] != 8'd0) begin
                            total_books = total_books + 8'd1;
                            if (init_arr_14[j] == target_arr_14[j]) begin
                                correct_books = correct_books + 8'd1;
                            end
                        end
                    end else if (i == 15) begin
                        if (init_arr_15[j] != 8'd0) begin
                            total_books = total_books + 8'd1;
                            if (init_arr_15[j] == target_arr_15[j]) begin
                                correct_books = correct_books + 8'd1;
                            end
                        end
                    end
                end
            end
        end

        for (k = 0; k < 256; k = k + 1) begin
            init_book_count[k] = 8'd0;
            target_book_count[k] = 8'd0;
        end

        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                if (i < N && j < M) begin
                    if (i == 0) begin
                        if (init_arr_0[j] != 8'd0) begin
                            init_book_count[init_arr_0[j]] = init_book_count[init_arr_0[j]] + 8'd1;
                        end
                        if (target_arr_0[j] != 8'd0) begin
                            target_book_count[target_arr_0[j]] = target_book_count[target_arr_0[j]] + 8'd1;
                        end
                    end else if (i == 1) begin
                        if (init_arr_1[j] != 8'd0) begin
                            init_book_count[init_arr_1[j]] = init_book_count[init_arr_1[j]] + 8'd1;
                        end
                        if (target_arr_1[j] != 8'd0) begin
                            target_book_count[target_arr_1[j]] = target_book_count[target_arr_1[j]] + 8'd1;
                        end
                    end else if (i == 2) begin
                        if (init_arr_2[j] != 8'd0) begin
                            init_book_count[init_arr_2[j]] = init_book_count[init_arr_2[j]] + 8'd1;
                        end
                        if (target_arr_2[j] != 8'd0) begin
                            target_book_count[target_arr_2[j]] = target_book_count[target_arr_2[j]] + 8'd1;
                        end
                    end else if (i == 3) begin
                        if (init_arr_3[j] != 8'd0) begin
                            init_book_count[init_arr_3[j]] = init_book_count[init_arr_3[j]] + 8'd1;
                        end
                        if (target_arr_3[j] != 8'd0) begin
                            target_book_count[target_arr_3[j]] = target_book_count[target_arr_3[j]] + 8'd1;
                        end
                    end else if (i == 4) begin
                        if (init_arr_4[j] != 8'd0) begin
                            init_book_count[init_arr_4[j]] = init_book_count[init_arr_4[j]] + 8'd1;
                        end
                        if (target_arr_4[j] != 8'd0) begin
                            target_book_count[target_arr_4[j]] = target_book_count[target_arr_4[j]] + 8'd1;
                        end
                    end else if (i == 5) begin
                        if (init_arr_5[j] != 8'd0) begin
                            init_book_count[init_arr_5[j]] = init_book_count[init_arr_5[j]] + 8'd1;
                        end
                        if (target_arr_5[j] != 8'd0) begin
                            target_book_count[target_arr_5[j]] = target_book_count[target_arr_5[j]] + 8'd1;
                        end
                    end else if (i == 6) begin
                        if (init_arr_6[j] != 8'd0) begin
                            init_book_count[init_arr_6[j]] = init_book_count[init_arr_6[j]] + 8'd1;
                        end
                        if (target_arr_6[j] != 8'd0) begin
                            target_book_count[target_arr_6[j]] = target_book_count[target_arr_6[j]] + 8'd1;
                        end
                    end else if (i == 7) begin
                        if (init_arr_7[j] != 8'd0) begin
                            init_book_count[init_arr_7[j]] = init_book_count[init_arr_7[j]] + 8'd1;
                        end
                        if (target_arr_7[j] != 8'd0) begin
                            target_book_count[target_arr_7[j]] = target_book_count[target_arr_7[j]] + 8'd1;
                        end
                    end else if (i == 8) begin
                        if (init_arr_8[j] != 8'd0) begin
                            init_book_count[init_arr_8[j]] = init_book_count[init_arr_8[j]] + 8'd1;
                        end
                        if (target_arr_8[j] != 8'd0) begin
                            target_book_count[target_arr_8[j]] = target_book_count[target_arr_8[j]] + 8'd1;
                        end
                    end else if (i == 9) begin
                        if (init_arr_9[j] != 8'd0) begin
                            init_book_count[init_arr_9[j]] = init_book_count[init_arr_9[j]] + 8'd1;
                        end
                        if (target_arr_9[j] != 8'd0) begin
                            target_book_count[target_arr_9[j]] = target_book_count[target_arr_9[j]] + 8'd1;
                        end
                    end else if (i == 10) begin
                        if (init_arr_10[j] != 8'd0) begin
                            init_book_count[init_arr_10[j]] = init_book_count[init_arr_10[j]] + 8'd1;
                        end
                        if (target_arr_10[j] != 8'd0) begin
                            target_book_count[target_arr_10[j]] = target_book_count[target_arr_10[j]] + 8'd1;
                        end
                    end else if (i == 11) begin
                        if (init_arr_11[j] != 8'd0) begin
                            init_book_count[init_arr_11[j]] = init_book_count[init_arr_11[j]] + 8'd1;
                        end
                        if (target_arr_11[j] != 8'd0) begin
                            target_book_count[target_arr_11[j]] = target_book_count[target_arr_11[j]] + 8'd1;
                        end
                    end else if (i == 12) begin
                        if (init_arr_12[j] != 8'd0) begin
                            init_book_count[init_arr_12[j]] = init_book_count[init_arr_12[j]] + 8'd1;
                        end
                        if (target_arr_12[j] != 8'd0) begin
                            target_book_count[target_arr_12[j]] = target_book_count[target_arr_12[j]] + 8'd1;
                        end
                    end else if (i == 13) begin
                        if (init_arr_13[j] != 8'd0) begin
                            init_book_count[init_arr_13[j]] = init_book_count[init_arr_13[j]] + 8'd1;
                        end
                        if (target_arr_13[j] != 8'd0) begin
                            target_book_count[target_arr_13[j]] = target_book_count[target_arr_13[j]] + 8'd1;
                        end
                    end else if (i == 14) begin
                        if (init_arr_14[j] != 8'd0) begin
                            init_book_count[init_arr_14[j]] = init_book_count[init_arr_14[j]] + 8'd1;
                        end
                        if (target_arr_14[j] != 8'd0) begin
                            target_book_count[target_arr_14[j]] = target_book_count[target_arr_14[j]] + 8'd1;
                        end
                    end else if (i == 15) begin
                        if (init_arr_15[j] != 8'd0) begin
                            init_book_count[init_arr_15[j]] = init_book_count[init_arr_15[j]] + 8'd1;
                        end
                        if (target_arr_15[j] != 8'd0) begin
                            target_book_count[target_arr_15[j]] = target_book_count[target_arr_15[j]] + 8'd1;
                        end
                    end
                end
            end
        end

        error = 1'b0;
        for (k = 1; k < 256; k = k + 1) begin
            if (init_book_count[k] != target_book_count[k]) begin
                error = 1'b1;
            end
        end

        if (error) begin
            lifts = 8'd255;
        end else begin
            lifts = total_books - correct_books;
        end
    end
endmodule