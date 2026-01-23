module bingo_tie_check (
    input [6:0] card1_row0,
    input [6:0] card1_row1,
    input [6:0] card1_row2,
    input [6:0] card1_row3,
    input [6:0] card1_row4,
    input [6:0] card1_row5,
    input [6:0] card1_row6,
    input [6:0] card1_row7,
    input [6:0] card2_row0,
    input [6:0] card2_row1,
    input [6:0] card2_row2,
    input [6:0] card2_row3,
    input [6:0] card2_row4,
    input [6:0] card2_row5,
    input [6:0] card2_row6,
    input [6:0] card2_row7,
    output tie_possible,
    output [2:0] tie_row1,
    output [2:0] tie_row2,
    output [6:0] last_number
);

    reg [2:0] card1_rows [0:7];
    reg [2:0] card2_rows [0:7];
    reg [6:0] card1_data [0:7][0:7];
    reg [6:0] card2_data [0:7][0:7];
    reg [6:0] common_num;
    reg [2:0] r1, r2;
    reg [2:0] found_r1, found_r2;
    reg [6:0] found_num;
    reg found;
    integer i, j, k, l;

    // Flatten card rows into arrays
    assign card1_rows[0] = card1_row0;
    assign card1_rows[1] = card1_row1;
    assign card1_rows[2] = card1_row2;
    assign card1_rows[3] = card1_row3;
    assign card1_rows[4] = card1_row4;
    assign card1_rows[5] = card1_row5;
    assign card1_rows[6] = card1_row6;
    assign card1_rows[7] = card1_row7;

    assign card2_rows[0] = card2_row0;
    assign card2_rows[1] = card2_row1;
    assign card2_rows[2] = card2_row2;
    assign card2_rows[3] = card2_row3;
    assign card2_rows[4] = card2_row4;
    assign card2_rows[5] = card2_row5;
    assign card2_rows[6] = card2_row6;
    assign card2_rows[7] = card2_row7;

    // Initialize outputs
    assign tie_possible = found;
    assign tie_row1 = found_r1;
    assign tie_row2 = found_r2;
    assign last_number = found_num;

    // Check all row pairs
    always @(*) begin
        found = 0;
        found_r1 = 0;
        found_r2 = 0;
        found_num = 0;

        for (r1 = 0; r1 < 8; r1 = r1 + 1) begin
            for (r2 = 0; r2 < 8; r2 = r2 + 1) begin
                // Check for common numbers between the two rows
                for (i = 0; i < 8; i = i + 1) begin
                    for (j = 0; j < 8; j = j + 1) begin
                        if (card1_rows[r1][i] == card2_rows[r2][j]) begin
                            common_num = card1_rows[r1][i];
                            // Check if all other numbers in both rows are unique and not equal to common_num
                            reg [6:0] temp_num;
                            reg valid;
                            valid = 1;

                            // Check card1 row
                            for (k = 0; k < 8; k = k + 1) begin
                                temp_num = card1_rows[r1][k];
                                if (temp_num != common_num) begin
                                    // Check if temp_num appears in card2 row (excluding common_num)
                                    for (l = 0; l < 8; l = l + 1) begin
                                        if (card2_rows[r2][l] == temp_num && temp_num != common_num) begin
                                            valid = 0;
                                        end
                                    end
                                end
                            end

                            // Check card2 row
                            for (k = 0; k < 8; k = k + 1) begin
                                temp_num = card2_rows[r2][k];
                                if (temp_num != common_num) begin
                                    // Check if temp_num appears in card1 row (excluding common_num)
                                    for (l = 0; l < 8; l = l + 1) begin
                                        if (card1_rows[r1][l] == temp_num && temp_num != common_num) begin
                                            valid = 0;
                                        end
                                    end
                                end
                            end

                            if (valid) begin
                                found = 1;
                                found_r1 = r1;
                                found_r2 = r2;
                                found_num = common_num;
                            end
                        end
                    end
                end
            end
        end
    end

endmodule