module BingoTwoCardChecker (
    input [11:0] card1_0_0, input [11:0] card1_0_1, input [11:0] card1_0_2, input [11:0] card1_0_3, input [11:0] card1_0_4,
    input [11:0] card1_1_0, input [11:0] card1_1_1, input [11:0] card1_1_2, input [11:0] card1_1_3, input [11:0] card1_1_4,
    input [11:0] card1_2_0, input [11:0] card1_2_1, input [11:0] card1_2_2, input [11:0] card1_2_3, input [11:0] card1_2_4,
    input [11:0] card1_3_0, input [11:0] card1_3_1, input [11:0] card1_3_2, input [11:0] card1_3_3, input [11:0] card1_3_4,
    input [11:0] card1_4_0, input [11:0] card1_4_1, input [11:0] card1_4_2, input [11:0] card1_4_3, input [11:0] card1_4_4,
    input [11:0] card2_0_0, input [11:0] card2_0_1, input [11:0] card2_0_2, input [11:0] card2_0_3, input [11:0] card2_0_4,
    input [11:0] card2_1_0, input [11:0] card2_1_1, input [11:0] card2_1_2, input [11:0] card2_1_3, input [11:0] card2_1_4,
    input [11:0] card2_2_0, input [11:0] card2_2_1, input [11:0] card2_2_2, input [11:0] card2_2_3, input [11:0] card2_2_4,
    input [11:0] card2_3_0, input [11:0] card2_3_1, input [11:0] card2_3_2, input [11:0] card2_3_3, input [11:0] card2_3_4,
    input [11:0] card2_4_0, input [11:0] card2_4_1, input [11:0] card2_4_2, input [11:0] card2_4_3, input [11:0] card2_4_4,
    output reg tie_found,
    output reg [2:0] tie_row1,
    output reg [2:0] tie_row2
);

    // Parameters
    localparam ROWS = 5;
    localparam COLS = 5;
    localparam DATA_WIDTH = 12;
    localparam MAX_UNION_SIZE = 10;
    localparam MAX_INTERSECTION_SIZE = 5;

    // Internal helper function: check if a number is in an array
    function automatic int is_in_array(
        input [DATA_WIDTH-1:0] num,
        input [DATA_WIDTH-1:0] arr_0,
        input [DATA_WIDTH-1:0] arr_1,
        input [DATA_WIDTH-1:0] arr_2,
        input [DATA_WIDTH-1:0] arr_3,
        input [DATA_WIDTH-1:0] arr_4,
        input [DATA_WIDTH-1:0] arr_5,
        input [DATA_WIDTH-1:0] arr_6,
        input [DATA_WIDTH-1:0] arr_7,
        input [DATA_WIDTH-1:0] arr_8,
        input [DATA_WIDTH-1:0] arr_9,
        input int size
    );
        is_in_array = 0;
        if (size > 0 && arr_0 == num) is_in_array = 1;
        if (size > 1 && arr_1 == num) is_in_array = 1;
        if (size > 2 && arr_2 == num) is_in_array = 1;
        if (size > 3 && arr_3 == num) is_in_array = 1;
        if (size > 4 && arr_4 == num) is_in_array = 1;
        if (size > 5 && arr_5 == num) is_in_array = 1;
        if (size > 6 && arr_6 == num) is_in_array = 1;
        if (size > 7 && arr_7 == num) is_in_array = 1;
        if (size > 8 && arr_8 == num) is_in_array = 1;
        if (size > 9 && arr_9 == num) is_in_array = 1;
    endfunction

    // Main combinational logic
    always @(*) begin
        // Initialize outputs
        tie_found = 0;
        tie_row1 = 0;
        tie_row2 = 0;

        // Iterate over each row in card1
        for (int i = 0; i < ROWS; i = i + 1) begin
            // Iterate over each row in card2
            for (int j = 0; j < ROWS; j = j + 1) begin
                // Compute intersection of row i and row j
                reg [DATA_WIDTH-1:0] inter_0, inter_1, inter_2, inter_3, inter_4;
                int inter_size = 0;
                for (int k = 0; k < COLS; k = k + 1) begin
                    for (int l = 0; l < COLS; l = l + 1) begin
                        if (i == 0 && k == 0) begin
                            if (card1_0_0 == card2_0_0 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_0_0)) begin
                                    inter_0 = card1_0_0; inter_size = 1;
                                end
                            end
                        end
                        if (i == 0 && k == 1) begin
                            if (card1_0_1 == card2_0_0 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_0_1)) begin
                                    inter_0 = card1_0_1; inter_size = 1;
                                end
                            end
                            if (card1_0_1 == card2_0_1 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_0_1)) begin
                                    inter_0 = card1_0_1; inter_size = 1;
                                end
                            end
                            if (card1_0_1 == card2_0_2 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_0_1)) begin
                                    inter_0 = card1_0_1; inter_size = 1;
                                end
                            end
                            if (card1_0_1 == card2_0_3 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_0_1)) begin
                                    inter_0 = card1_0_1; inter_size = 1;
                                end
                            end
                            if (card1_0_1 == card2_0_4 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_0_1)) begin
                                    inter_0 = card1_0_1; inter_size = 1;
                                end
                            end
                        end
                        if (i == 0 && k == 2) begin
                            if (card1_0_2 == card2_0_0 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_0_2)) begin
                                    inter_0 = card1_0_2; inter_size = 1;
                                end
                            end
                            if (card1_0_2 == card2_0_1 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_0_2)) begin
                                    inter_0 = card1_0_2; inter_size = 1;
                                end
                            end
                            if (card1_0_2 == card2_0_2 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_0_2)) begin
                                    inter_0 = card1_0_2; inter_size = 1;
                                end
                            end
                            if (card1_0_2 == card2_0_3 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_0_2)) begin
                                    inter_0 = card1_0_2; inter_size = 1;
                                end
                            end
                            if (card1_0_2 == card2_0_4 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_0_2)) begin
                                    inter_0 = card1_0_2; inter_size = 1;
                                end
                            end
                        end
                        if (i == 0 && k == 3) begin
                            if (card1_0_3 == card2_0_0 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_0_3)) begin
                                    inter_0 = card1_0_3; inter_size = 1;
                                end
                            end
                            if (card1_0_3 == card2_0_1 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_0_3)) begin
                                    inter_0 = card1_0_3; inter_size = 1;
                                end
                            end
                            if (card1_0_3 == card2_0_2 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_0_3)) begin
                                    inter_0 = card1_0_3; inter_size = 1;
                                end
                            end
                            if (card1_0_3 == card2_0_3 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_0_3)) begin
                                    inter_0 = card1_0_3; inter_size = 1;
                                end
                            end
                            if (card1_0_3 == card2_0_4 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_0_3)) begin
                                    inter_0 = card1_0_3; inter_size = 1;
                                end
                            end
                        end
                        if (i == 0 && k == 4) begin
                            if (card1_0_4 == card2_0_0 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_0_4)) begin
                                    inter_0 = card1_0_4; inter_size = 1;
                                end
                            end
                            if (card1_0_4 == card2_0_1 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_0_4)) begin
                                    inter_0 = card1_0_4; inter_size = 1;
                                end
                            end
                            if (card1_0_4 == card2_0_2 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_0_4)) begin
                                    inter_0 = card1_0_4; inter_size = 1;
                                end
                            end
                            if (card1_0_4 == card2_0_3 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_0_4)) begin
                                    inter_0 = card1_0_4; inter_size = 1;
                                end
                            end
                            if (card1_0_4 == card2_0_4 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_0_4)) begin
                                    inter_0 = card1_0_4; inter_size = 1;
                                end
                            end
                        end
                        if (i == 1 && k == 0) begin
                            if (card1_1_0 == card2_0_0 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_1_0)) begin
                                    inter_0 = card1_1_0; inter_size = 1;
                                end
                            end
                            if (card1_1_0 == card2_0_1 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_1_0)) begin
                                    inter_0 = card1_1_0; inter_size = 1;
                                end
                            end
                            if (card1_1_0 == card2_0_2 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_1_0)) begin
                                    inter_0 = card1_1_0; inter_size = 1;
                                end
                            end
                            if (card1_1_0 == card2_0_3 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_1_0)) begin
                                    inter_0 = card1_1_0; inter_size = 1;
                                end
                            end
                            if (card1_1_0 == card2_0_4 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_1_0)) begin
                                    inter_0 = card1_1_0; inter_size = 1;
                                end
                            end
                        end
                        if (i == 1 && k == 1) begin
                            if (card1_1_1 == card2_0_0 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_1_1)) begin
                                    inter_0 = card1_1_1; inter_size = 1;
                                end
                            end
                            if (card1_1_1 == card2_0_1 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_1_1)) begin
                                    inter_0 = card1_1_1; inter_size = 1;
                                end
                            end
                            if (card1_1_1 == card2_0_2 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_1_1)) begin
                                    inter_0 = card1_1_1; inter_size = 1;
                                end
                            end
                            if (card1_1_1 == card2_0_3 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_1_1)) begin
                                    inter_0 = card1_1_1; inter_size = 1;
                                end
                            end
                            if (card1_1_1 == card2_0_4 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_1_1)) begin
                                    inter_0 = card1_1_1; inter_size = 1;
                                end
                            end
                        end
                        if (i == 1 && k == 2) begin
                            if (card1_1_2 == card2_0_0 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_1_2)) begin
                                    inter_0 = card1_1_2; inter_size = 1;
                                end
                            end
                            if (card1_1_2 == card2_0_1 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_1_2)) begin
                                    inter_0 = card1_1_2; inter_size = 1;
                                end
                            end
                            if (card1_1_2 == card2_0_2 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_1_2)) begin
                                    inter_0 = card1_1_2; inter_size = 1;
                                end
                            end
                            if (card1_1_2 == card2_0_3 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_1_2)) begin
                                    inter_0 = card1_1_2; inter_size = 1;
                                end
                            end
                            if (card1_1_2 == card2_0_4 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_1_2)) begin
                                    inter_0 = card1_1_2; inter_size = 1;
                                end
                            end
                        end
                        if (i == 1 && k == 3) begin
                            if (card1_1_3 == card2_0_0 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_1_3)) begin
                                    inter_0 = card1_1_3; inter_size = 1;
                                end
                            end
                            if (card1_1_3 == card2_0_1 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_1_3)) begin
                                    inter_0 = card1_1_3; inter_size = 1;
                                end
                            end
                            if (card1_1_3 == card2_0_2 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_1_3)) begin
                                    inter_0 = card1_1_3; inter_size = 1;
                                end
                            end
                            if (card1_1_3 == card2_0_3 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_1_3)) begin
                                    inter_0 = card1_1_3; inter_size = 1;
                                end
                            end
                            if (card1_1_3 == card2_0_4 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_1_3)) begin
                                    inter_0 = card1_1_3; inter_size = 1;
                                end
                            end
                        end
                        if (i == 1 && k == 4) begin
                            if (card1_1_4 == card2_0_0 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_1_4)) begin
                                    inter_0 = card1_1_4; inter_size = 1;
                                end
                            end
                            if (card1_1_4 == card2_0_1 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_1_4)) begin
                                    inter_0 = card1_1_4; inter_size = 1;
                                end
                            end
                            if (card1_1_4 == card2_0_2 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_1_4)) begin
                                    inter_0 = card1_1_4; inter_size = 1;
                                end
                            end
                            if (card1_1_4 == card2_0_3 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_1_4)) begin
                                    inter_0 = card1_1_4; inter_size = 1;
                                end
                            end
                            if (card1_1_4 == card2_0_4 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_1_4)) begin
                                    inter_0 = card1_1_4; inter_size = 1;
                                end
                            end
                        end
                        if (i == 2 && k == 0) begin
                            if (card1_2_0 == card2_0_0 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_2_0)) begin
                                    inter_0 = card1_2_0; inter_size = 1;
                                end
                            end
                            if (card1_2_0 == card2_0_1 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_2_0)) begin
                                    inter_0 = card1_2_0; inter_size = 1;
                                end
                            end
                            if (card1_2_0 == card2_0_2 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_2_0)) begin
                                    inter_0 = card1_2_0; inter_size = 1;
                                end
                            end
                            if (card1_2_0 == card2_0_3 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_2_0)) begin
                                    inter_0 = card1_2_0; inter_size = 1;
                                end
                            end
                            if (card1_2_0 == card2_0_4 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_2_0)) begin
                                    inter_0 = card1_2_0; inter_size = 1;
                                end
                            end
                        end
                        if (i == 2 && k == 1) begin
                            if (card1_2_1 == card2_0_0 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_2_1)) begin
                                    inter_0 = card1_2_1; inter_size = 1;
                                end
                            end
                            if (card1_2_1 == card2_0_1 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_2_1)) begin
                                    inter_0 = card1_2_1; inter_size = 1;
                                end
                            end
                            if (card1_2_1 == card2_0_2 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_2_1)) begin
                                    inter_0 = card1_2_1; inter_size = 1;
                                end
                            end
                            if (card1_2_1 == card2_0_3 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_2_1)) begin
                                    inter_0 = card1_2_1; inter_size = 1;
                                end
                            end
                            if (card1_2_1 == card2_0_4 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_2_1)) begin
                                    inter_0 = card1_2_1; inter_size = 1;
                                end
                            end
                        end
                        if (i == 2 && k == 2) begin
                            if (card1_2_2 == card2_0_0 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_2_2)) begin
                                    inter_0 = card1_2_2; inter_size = 1;
                                end
                            end
                            if (card1_2_2 == card2_0_1 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_2_2)) begin
                                    inter_0 = card1_2_2; inter_size = 1;
                                end
                            end
                            if (card1_2_2 == card2_0_2 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_2_2)) begin
                                    inter_0 = card1_2_2; inter_size = 1;
                                end
                            end
                            if (card1_2_2 == card2_0_3 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_2_2)) begin
                                    inter_0 = card1_2_2; inter_size = 1;
                                end
                            end
                            if (card1_2_2 == card2_0_4 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_2_2)) begin
                                    inter_0 = card1_2_2; inter_size = 1;
                                end
                            end
                        end
                        if (i == 2 && k == 3) begin
                            if (card1_2_3 == card2_0_0 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_2_3)) begin
                                    inter_0 = card1_2_3; inter_size = 1;
                                end
                            end
                            if (card1_2_3 == card2_0_1 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_2_3)) begin
                                    inter_0 = card1_2_3; inter_size = 1;
                                end
                            end
                            if (card1_2_3 == card2_0_2 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_2_3)) begin
                                    inter_0 = card1_2_3; inter_size = 1;
                                end
                            end
                            if (card1_2_3 == card2_0_3 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_2_3)) begin
                                    inter_0 = card1_2_3; inter_size = 1;
                                end
                            end
                            if (card1_2_3 == card2_0_4 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_2_3)) begin
                                    inter_0 = card1_2_3; inter_size = 1;
                                end
                            end
                        end
                        if (i == 2 && k == 4) begin
                            if (card1_2_4 == card2_0_0 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_2_4)) begin
                                    inter_0 = card1_2_4; inter_size = 1;
                                end
                            end
                            if (card1_2_4 == card2_0_1 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_2_4)) begin
                                    inter_0 = card1_2_4; inter_size = 1;
                                end
                            end
                            if (card1_2_4 == card2_0_2 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_2_4)) begin
                                    inter_0 = card1_2_4; inter_size = 1;
                                end
                            end
                            if (card1_2_4 == card2_0_3 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_2_4)) begin
                                    inter_0 = card1_2_4; inter_size = 1;
                                end
                            end
                            if (card1_2_4 == card2_0_4 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_2_4)) begin
                                    inter_0 = card1_2_4; inter_size = 1;
                                end
                            end
                        end
                        if (i == 3 && k == 0) begin
                            if (card1_3_0 == card2_0_0 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_3_0)) begin
                                    inter_0 = card1_3_0; inter_size = 1;
                                end
                            end
                            if (card1_3_0 == card2_0_1 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_3_0)) begin
                                    inter_0 = card1_3_0; inter_size = 1;
                                end
                            end
                            if (card1_3_0 == card2_0_2 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_3_0)) begin
                                    inter_0 = card1_3_0; inter_size = 1;
                                end
                            end
                            if (card1_3_0 == card2_0_3 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_3_0)) begin
                                    inter_0 = card1_3_0; inter_size = 1;
                                end
                            end
                            if (card1_3_0 == card2_0_4 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_3_0)) begin
                                    inter_0 = card1_3_0; inter_size = 1;
                                end
                            end
                        end
                        if (i == 3 && k == 1) begin
                            if (card1_3_1 == card2_0_0 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_3_1)) begin
                                    inter_0 = card1_3_1; inter_size = 1;
                                end
                            end
                            if (card1_3_1 == card2_0_1 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_3_1)) begin
                                    inter_0 = card1_3_1; inter_size = 1;
                                end
                            end
                            if (card1_3_1 == card2_0_2 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_3_1)) begin
                                    inter_0 = card1_3_1; inter_size = 1;
                                end
                            end
                            if (card1_3_1 == card2_0_3 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_3_1)) begin
                                    inter_0 = card1_3_1; inter_size = 1;
                                end
                            end
                            if (card1_3_1 == card2_0_4 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_3_1)) begin
                                    inter_0 = card1_3_1; inter_size = 1;
                                end
                            end
                        end
                        if (i == 3 && k == 2) begin
                            if (card1_3_2 == card2_0_0 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_3_2)) begin
                                    inter_0 = card1_3_2; inter_size = 1;
                                end
                            end
                            if (card1_3_2 == card2_0_1 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_3_2)) begin
                                    inter_0 = card1_3_2; inter_size = 1;
                                end
                            end
                            if (card1_3_2 == card2_0_2 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_3_2)) begin
                                    inter_0 = card1_3_2; inter_size = 1;
                                end
                            end
                            if (card1_3_2 == card2_0_3 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_3_2)) begin
                                    inter_0 = card1_3_2; inter_size = 1;
                                end
                            end
                            if (card1_3_2 == card2_0_4 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_3_2)) begin
                                    inter_0 = card1_3_2; inter_size = 1;
                                end
                            end
                        end
                        if (i == 3 && k == 3) begin
                            if (card1_3_3 == card2_0_0 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_3_3)) begin
                                    inter_0 = card1_3_3; inter_size = 1;
                                end
                            end
                            if (card1_3_3 == card2_0_1 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_3_3)) begin
                                    inter_0 = card1_3_3; inter_size = 1;
                                end
                            end
                            if (card1_3_3 == card2_0_2 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_3_3)) begin
                                    inter_0 = card1_3_3; inter_size = 1;
                                end
                            end
                            if (card1_3_3 == card2_0_3 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_3_3)) begin
                                    inter_0 = card1_3_3; inter_size = 1;
                                end
                            end
                            if (card1_3_3 == card2_0_4 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_3_3)) begin
                                    inter_0 = card1_3_3; inter_size = 1;
                                end
                            end
                        end
                        if (i == 3 && k == 4) begin
                            if (card1_3_4 == card2_0_0 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_3_4)) begin
                                    inter_0 = card1_3_4; inter_size = 1;
                                end
                            end
                            if (card1_3_4 == card2_0_1 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_3_4)) begin
                                    inter_0 = card1_3_4; inter_size = 1;
                                end
                            end
                            if (card1_3_4 == card2_0_2 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_3_4)) begin
                                    inter_0 = card1_3_4; inter_size = 1;
                                end
                            end
                            if (card1_3_4 == card2_0_3 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_3_4)) begin
                                    inter_0 = card1_3_4; inter_size = 1;
                                end
                            end
                            if (card1_3_4 == card2_0_4 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_3_4)) begin
                                    inter_0 = card1_3_4; inter_size = 1;
                                end
                            end
                        end
                        if (i == 4 && k == 0) begin
                            if (card1_4_0 == card2_0_0 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_4_0)) begin
                                    inter_0 = card1_4_0; inter_size = 1;
                                end
                            end
                            if (card1_4_0 == card2_0_1 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_4_0)) begin
                                    inter_0 = card1_4_0; inter_size = 1;
                                end
                            end
                            if (card1_4_0 == card2_0_2 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_4_0)) begin
                                    inter_0 = card1_4_0; inter_size = 1;
                                end
                            end
                            if (card1_4_0 == card2_0_3 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_4_0)) begin
                                    inter_0 = card1_4_0; inter_size = 1;
                                end
                            end
                            if (card1_4_0 == card2_0_4 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_4_0)) begin
                                    inter_0 = card1_4_0; inter_size = 1;
                                end
                            end
                        end
                        if (i == 4 && k == 1) begin
                            if (card1_4_1 == card2_0_0 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_4_1)) begin
                                    inter_0 = card1_4_1; inter_size = 1;
                                end
                            end
                            if (card1_4_1 == card2_0_1 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_4_1)) begin
                                    inter_0 = card1_4_1; inter_size = 1;
                                end
                            end
                            if (card1_4_1 == card2_0_2 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_4_1)) begin
                                    inter_0 = card1_4_1; inter_size = 1;
                                end
                            end
                            if (card1_4_1 == card2_0_3 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_4_1)) begin
                                    inter_0 = card1_4_1; inter_size = 1;
                                end
                            end
                            if (card1_4_1 == card2_0_4 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_4_1)) begin
                                    inter_0 = card1_4_1; inter_size = 1;
                                end
                            end
                        end
                        if (i == 4 && k == 2) begin
                            if (card1_4_2 == card2_0_0 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_4_2)) begin
                                    inter_0 = card1_4_2; inter_size = 1;
                                end
                            end
                            if (card1_4_2 == card2_0_1 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_4_2)) begin
                                    inter_0 = card1_4_2; inter_size = 1;
                                end
                            end
                            if (card1_4_2 == card2_0_2 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_4_2)) begin
                                    inter_0 = card1_4_2; inter_size = 1;
                                end
                            end
                            if (card1_4_2 == card2_0_3 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_4_2)) begin
                                    inter_0 = card1_4_2; inter_size = 1;
                                end
                            end
                            if (card1_4_2 == card2_0_4 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_4_2)) begin
                                    inter_0 = card1_4_2; inter_size = 1;
                                end
                            end
                        end
                        if (i == 4 && k == 3) begin
                            if (card1_4_3 == card2_0_0 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_4_3)) begin
                                    inter_0 = card1_4_3; inter_size = 1;
                                end
                            end
                            if (card1_4_3 == card2_0_1 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_4_3)) begin
                                    inter_0 = card1_4_3; inter_size = 1;
                                end
                            end
                            if (card1_4_3 == card2_0_2 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_4_3)) begin
                                    inter_0 = card1_4_3; inter_size = 1;
                                end
                            end
                            if (card1_4_3 == card2_0_3 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_4_3)) begin
                                    inter_0 = card1_4_3; inter_size = 1;
                                end
                            end
                            if (card1_4_3 == card2_0_4 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_4_3)) begin
                                    inter_0 = card1_4_3; inter_size = 1;
                                end
                            end
                        end
                        if (i == 4 && k == 4) begin
                            if (card1_4_4 == card2_0_0 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_4_4)) begin
                                    inter_0 = card1_4_4; inter_size = 1;
                                end
                            end
                            if (card1_4_4 == card2_0_1 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_4_4)) begin
                                    inter_0 = card1_4_4; inter_size = 1;
                                end
                            end
                            if (card1_4_4 == card2_0_2 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_4_4)) begin
                                    inter_0 = card1_4_4; inter_size = 1;
                                end
                            end
                            if (card1_4_4 == card2_0_3 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_4_4)) begin
                                    inter_0 = card1_4_4; inter_size = 1;
                                end
                            end
                            if (card1_4_4 == card2_0_4 && inter_size < MAX_INTERSECTION_SIZE) begin
                                if (inter_size == 0 || (inter_0 != card1_4_4)) begin
                                    inter_0 = card1_4_4; inter_size = 1;
                                end
                            end
                        end
                    end
                end

                // Compute union of row i and row j
                reg [DATA_WIDTH-1:0] uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9;
                int uni_size = 0;
                // Add all from row i
                if (i == 0) begin
                    if (!is_in_array(card1_0_0, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        uni_0 = card1_0_0; uni_size = 1;
                    end
                    if (!is_in_array(card1_0_1, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card1_0_1; else if (uni_size == 1) uni_1 = card1_0_1; else if (uni_size == 2) uni_2 = card1_0_1; else if (uni_size == 3) uni_3 = card1_0_1; else if (uni_size == 4) uni_4 = card1_0_1; else if (uni_size == 5) uni_5 = card1_0_1; else if (uni_size == 6) uni_6 = card1_0_1; else if (uni_size == 7) uni_7 = card1_0_1; else if (uni_size == 8) uni_8 = card1_0_1; else if (uni_size == 9) uni_9 = card1_0_1;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card1_0_2, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card1_0_2; else if (uni_size == 1) uni_1 = card1_0_2; else if (uni_size == 2) uni_2 = card1_0_2; else if (uni_size == 3) uni_3 = card1_0_2; else if (uni_size == 4) uni_4 = card1_0_2; else if (uni_size == 5) uni_5 = card1_0_2; else if (uni_size == 6) uni_6 = card1_0_2; else if (uni_size == 7) uni_7 = card1_0_2; else if (uni_size == 8) uni_8 = card1_0_2; else if (uni_size == 9) uni_9 = card1_0_2;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card1_0_3, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card1_0_3; else if (uni_size == 1) uni_1 = card1_0_3; else if (uni_size == 2) uni_2 = card1_0_3; else if (uni_size == 3) uni_3 = card1_0_3; else if (uni_size == 4) uni_4 = card1_0_3; else if (uni_size == 5) uni_5 = card1_0_3; else if (uni_size == 6) uni_6 = card1_0_3; else if (uni_size == 7) uni_7 = card1_0_3; else if (uni_size == 8) uni_8 = card1_0_3; else if (uni_size == 9) uni_9 = card1_0_3;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card1_0_4, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card1_0_4; else if (uni_size == 1) uni_1 = card1_0_4; else if (uni_size == 2) uni_2 = card1_0_4; else if (uni_size == 3) uni_3 = card1_0_4; else if (uni_size == 4) uni_4 = card1_0_4; else if (uni_size == 5) uni_5 = card1_0_4; else if (uni_size == 6) uni_6 = card1_0_4; else if (uni_size == 7) uni_7 = card1_0_4; else if (uni_size == 8) uni_8 = card1_0_4; else if (uni_size == 9) uni_9 = card1_0_4;
                        uni_size = uni_size + 1;
                    end
                end
                if (i == 1) begin
                    if (!is_in_array(card1_1_0, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card1_1_0; else if (uni_size == 1) uni_1 = card1_1_0; else if (uni_size == 2) uni_2 = card1_1_0; else if (uni_size == 3) uni_3 = card1_1_0; else if (uni_size == 4) uni_4 = card1_1_0; else if (uni_size == 5) uni_5 = card1_1_0; else if (uni_size == 6) uni_6 = card1_1_0; else if (uni_size == 7) uni_7 = card1_1_0; else if (uni_size == 8) uni_8 = card1_1_0; else if (uni_size == 9) uni_9 = card1_1_0;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card1_1_1, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card1_1_1; else if (uni_size == 1) uni_1 = card1_1_1; else if (uni_size == 2) uni_2 = card1_1_1; else if (uni_size == 3) uni_3 = card1_1_1; else if (uni_size == 4) uni_4 = card1_1_1; else if (uni_size == 5) uni_5 = card1_1_1; else if (uni_size == 6) uni_6 = card1_1_1; else if (uni_size == 7) uni_7 = card1_1_1; else if (uni_size == 8) uni_8 = card1_1_1; else if (uni_size == 9) uni_9 = card1_1_1;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card1_1_2, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card1_1_2; else if (uni_size == 1) uni_1 = card1_1_2; else if (uni_size == 2) uni_2 = card1_1_2; else if (uni_size == 3) uni_3 = card1_1_2; else if (uni_size == 4) uni_4 = card1_1_2; else if (uni_size == 5) uni_5 = card1_1_2; else if (uni_size == 6) uni_6 = card1_1_2; else if (uni_size == 7) uni_7 = card1_1_2; else if (uni_size == 8) uni_8 = card1_1_2; else if (uni_size == 9) uni_9 = card1_1_2;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card1_1_3, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card1_1_3; else if (uni_size == 1) uni_1 = card1_1_3; else if (uni_size == 2) uni_2 = card1_1_3; else if (uni_size == 3) uni_3 = card1_1_3; else if (uni_size == 4) uni_4 = card1_1_3; else if (uni_size == 5) uni_5 = card1_1_3; else if (uni_size == 6) uni_6 = card1_1_3; else if (uni_size == 7) uni_7 = card1_1_3; else if (uni_size == 8) uni_8 = card1_1_3; else if (uni_size == 9) uni_9 = card1_1_3;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card1_1_4, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card1_1_4; else if (uni_size == 1) uni_1 = card1_1_4; else if (uni_size == 2) uni_2 = card1_1_4; else if (uni_size == 3) uni_3 = card1_1_4; else if (uni_size == 4) uni_4 = card1_1_4; else if (uni_size == 5) uni_5 = card1_1_4; else if (uni_size == 6) uni_6 = card1_1_4; else if (uni_size == 7) uni_7 = card1_1_4; else if (uni_size == 8) uni_8 = card1_1_4; else if (uni_size == 9) uni_9 = card1_1_4;
                        uni_size = uni_size + 1;
                    end
                end
                if (i == 2) begin
                    if (!is_in_array(card1_2_0, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card1_2_0; else if (uni_size == 1) uni_1 = card1_2_0; else if (uni_size == 2) uni_2 = card1_2_0; else if (uni_size == 3) uni_3 = card1_2_0; else if (uni_size == 4) uni_4 = card1_2_0; else if (uni_size == 5) uni_5 = card1_2_0; else if (uni_size == 6) uni_6 = card1_2_0; else if (uni_size == 7) uni_7 = card1_2_0; else if (uni_size == 8) uni_8 = card1_2_0; else if (uni_size == 9) uni_9 = card1_2_0;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card1_2_1, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card1_2_1; else if (uni_size == 1) uni_1 = card1_2_1; else if (uni_size == 2) uni_2 = card1_2_1; else if (uni_size == 3) uni_3 = card1_2_1; else if (uni_size == 4) uni_4 = card1_2_1; else if (uni_size == 5) uni_5 = card1_2_1; else if (uni_size == 6) uni_6 = card1_2_1; else if (uni_size == 7) uni_7 = card1_2_1; else if (uni_size == 8) uni_8 = card1_2_1; else if (uni_size == 9) uni_9 = card1_2_1;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card1_2_2, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card1_2_2; else if (uni_size == 1) uni_1 = card1_2_2; else if (uni_size == 2) uni_2 = card1_2_2; else if (uni_size == 3) uni_3 = card1_2_2; else if (uni_size == 4) uni_4 = card1_2_2; else if (uni_size == 5) uni_5 = card1_2_2; else if (uni_size == 6) uni_6 = card1_2_2; else if (uni_size == 7) uni_7 = card1_2_2; else if (uni_size == 8) uni_8 = card1_2_2; else if (uni_size == 9) uni_9 = card1_2_2;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card1_2_3, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card1_2_3; else if (uni_size == 1) uni_1 = card1_2_3; else if (uni_size == 2) uni_2 = card1_2_3; else if (uni_size == 3) uni_3 = card1_2_3; else if (uni_size == 4) uni_4 = card1_2_3; else if (uni_size == 5) uni_5 = card1_2_3; else if (uni_size == 6) uni_6 = card1_2_3; else if (uni_size == 7) uni_7 = card1_2_3; else if (uni_size == 8) uni_8 = card1_2_3; else if (uni_size == 9) uni_9 = card1_2_3;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card1_2_4, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card1_2_4; else if (uni_size == 1) uni_1 = card1_2_4; else if (uni_size == 2) uni_2 = card1_2_4; else if (uni_size == 3) uni_3 = card1_2_4; else if (uni_size == 4) uni_4 = card1_2_4; else if (uni_size == 5) uni_5 = card1_2_4; else if (uni_size == 6) uni_6 = card1_2_4; else if (uni_size == 7) uni_7 = card1_2_4; else if (uni_size == 8) uni_8 = card1_2_4; else if (uni_size == 9) uni_9 = card1_2_4;
                        uni_size = uni_size + 1;
                    end
                end
                if (i == 3) begin
                    if (!is_in_array(card1_3_0, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card1_3_0; else if (uni_size == 1) uni_1 = card1_3_0; else if (uni_size == 2) uni_2 = card1_3_0; else if (uni_size == 3) uni_3 = card1_3_0; else if (uni_size == 4) uni_4 = card1_3_0; else if (uni_size == 5) uni_5 = card1_3_0; else if (uni_size == 6) uni_6 = card1_3_0; else if (uni_size == 7) uni_7 = card1_3_0; else if (uni_size == 8) uni_8 = card1_3_0; else if (uni_size == 9) uni_9 = card1_3_0;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card1_3_1, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card1_3_1; else if (uni_size == 1) uni_1 = card1_3_1; else if (uni_size == 2) uni_2 = card1_3_1; else if (uni_size == 3) uni_3 = card1_3_1; else if (uni_size == 4) uni_4 = card1_3_1; else if (uni_size == 5) uni_5 = card1_3_1; else if (uni_size == 6) uni_6 = card1_3_1; else if (uni_size == 7) uni_7 = card1_3_1; else if (uni_size == 8) uni_8 = card1_3_1; else if (uni_size == 9) uni_9 = card1_3_1;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card1_3_2, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card1_3_2; else if (uni_size == 1) uni_1 = card1_3_2; else if (uni_size == 2) uni_2 = card1_3_2; else if (uni_size == 3) uni_3 = card1_3_2; else if (uni_size == 4) uni_4 = card1_3_2; else if (uni_size == 5) uni_5 = card1_3_2; else if (uni_size == 6) uni_6 = card1_3_2; else if (uni_size == 7) uni_7 = card1_3_2; else if (uni_size == 8) uni_8 = card1_3_2; else if (uni_size == 9) uni_9 = card1_3_2;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card1_3_3, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card1_3_3; else if (uni_size == 1) uni_1 = card1_3_3; else if (uni_size == 2) uni_2 = card1_3_3; else if (uni_size == 3) uni_3 = card1_3_3; else if (uni_size == 4) uni_4 = card1_3_3; else if (uni_size == 5) uni_5 = card1_3_3; else if (uni_size == 6) uni_6 = card1_3_3; else if (uni_size == 7) uni_7 = card1_3_3; else if (uni_size == 8) uni_8 = card1_3_3; else if (uni_size == 9) uni_9 = card1_3_3;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card1_3_4, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card1_3_4; else if (uni_size == 1) uni_1 = card1_3_4; else if (uni_size == 2) uni_2 = card1_3_4; else if (uni_size == 3) uni_3 = card1_3_4; else if (uni_size == 4) uni_4 = card1_3_4; else if (uni_size == 5) uni_5 = card1_3_4; else if (uni_size == 6) uni_6 = card1_3_4; else if (uni_size == 7) uni_7 = card1_3_4; else if (uni_size == 8) uni_8 = card1_3_4; else if (uni_size == 9) uni_9 = card1_3_4;
                        uni_size = uni_size + 1;
                    end
                end
                if (i == 4) begin
                    if (!is_in_array(card1_4_0, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card1_4_0; else if (uni_size == 1) uni_1 = card1_4_0; else if (uni_size == 2) uni_2 = card1_4_0; else if (uni_size == 3) uni_3 = card1_4_0; else if (uni_size == 4) uni_4 = card1_4_0; else if (uni_size == 5) uni_5 = card1_4_0; else if (uni_size == 6) uni_6 = card1_4_0; else if (uni_size == 7) uni_7 = card1_4_0; else if (uni_size == 8) uni_8 = card1_4_0; else if (uni_size == 9) uni_9 = card1_4_0;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card1_4_1, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card1_4_1; else if (uni_size == 1) uni_1 = card1_4_1; else if (uni_size == 2) uni_2 = card1_4_1; else if (uni_size == 3) uni_3 = card1_4_1; else if (uni_size == 4) uni_4 = card1_4_1; else if (uni_size == 5) uni_5 = card1_4_1; else if (uni_size == 6) uni_6 = card1_4_1; else if (uni_size == 7) uni_7 = card1_4_1; else if (uni_size == 8) uni_8 = card1_4_1; else if (uni_size == 9) uni_9 = card1_4_1;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card1_4_2, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card1_4_2; else if (uni_size == 1) uni_1 = card1_4_2; else if (uni_size == 2) uni_2 = card1_4_2; else if (uni_size == 3) uni_3 = card1_4_2; else if (uni_size == 4) uni_4 = card1_4_2; else if (uni_size == 5) uni_5 = card1_4_2; else if (uni_size == 6) uni_6 = card1_4_2; else if (uni_size == 7) uni_7 = card1_4_2; else if (uni_size == 8) uni_8 = card1_4_2; else if (uni_size == 9) uni_9 = card1_4_2;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card1_4_3, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card1_4_3; else if (uni_size == 1) uni_1 = card1_4_3; else if (uni_size == 2) uni_2 = card1_4_3; else if (uni_size == 3) uni_3 = card1_4_3; else if (uni_size == 4) uni_4 = card1_4_3; else if (uni_size == 5) uni_5 = card1_4_3; else if (uni_size == 6) uni_6 = card1_4_3; else if (uni_size == 7) uni_7 = card1_4_3; else if (uni_size == 8) uni_8 = card1_4_3; else if (uni_size == 9) uni_9 = card1_4_3;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card1_4_4, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card1_4_4; else if (uni_size == 1) uni_1 = card1_4_4; else if (uni_size == 2) uni_2 = card1_4_4; else if (uni_size == 3) uni_3 = card1_4_4; else if (uni_size == 4) uni_4 = card1_4_4; else if (uni_size == 5) uni_5 = card1_4_4; else if (uni_size == 6) uni_6 = card1_4_4; else if (uni_size == 7) uni_7 = card1_4_4; else if (uni_size == 8) uni_8 = card1_4_4; else if (uni_size == 9) uni_9 = card1_4_4;
                        uni_size = uni_size + 1;
                    end
                end
                // Add all from row j
                if (j == 0) begin
                    if (!is_in_array(card2_0_0, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card2_0_0; else if (uni_size == 1) uni_1 = card2_0_0; else if (uni_size == 2) uni_2 = card2_0_0; else if (uni_size == 3) uni_3 = card2_0_0; else if (uni_size == 4) uni_4 = card2_0_0; else if (uni_size == 5) uni_5 = card2_0_0; else if (uni_size == 6) uni_6 = card2_0_0; else if (uni_size == 7) uni_7 = card2_0_0; else if (uni_size == 8) uni_8 = card2_0_0; else if (uni_size == 9) uni_9 = card2_0_0;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card2_0_1, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card2_0_1; else if (uni_size == 1) uni_1 = card2_0_1; else if (uni_size == 2) uni_2 = card2_0_1; else if (uni_size == 3) uni_3 = card2_0_1; else if (uni_size == 4) uni_4 = card2_0_1; else if (uni_size == 5) uni_5 = card2_0_1; else if (uni_size == 6) uni_6 = card2_0_1; else if (uni_size == 7) uni_7 = card2_0_1; else if (uni_size == 8) uni_8 = card2_0_1; else if (uni_size == 9) uni_9 = card2_0_1;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card2_0_2, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card2_0_2; else if (uni_size == 1) uni_1 = card2_0_2; else if (uni_size == 2) uni_2 = card2_0_2; else if (uni_size == 3) uni_3 = card2_0_2; else if (uni_size == 4) uni_4 = card2_0_2; else if (uni_size == 5) uni_5 = card2_0_2; else if (uni_size == 6) uni_6 = card2_0_2; else if (uni_size == 7) uni_7 = card2_0_2; else if (uni_size == 8) uni_8 = card2_0_2; else if (uni_size == 9) uni_9 = card2_0_2;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card2_0_3, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card2_0_3; else if (uni_size == 1) uni_1 = card2_0_3; else if (uni_size == 2) uni_2 = card2_0_3; else if (uni_size == 3) uni_3 = card2_0_3; else if (uni_size == 4) uni_4 = card2_0_3; else if (uni_size == 5) uni_5 = card2_0_3; else if (uni_size == 6) uni_6 = card2_0_3; else if (uni_size == 7) uni_7 = card2_0_3; else if (uni_size == 8) uni_8 = card2_0_3; else if (uni_size == 9) uni_9 = card2_0_3;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card2_0_4, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card2_0_4; else if (uni_size == 1) uni_1 = card2_0_4; else if (uni_size == 2) uni_2 = card2_0_4; else if (uni_size == 3) uni_3 = card2_0_4; else if (uni_size == 4) uni_4 = card2_0_4; else if (uni_size == 5) uni_5 = card2_0_4; else if (uni_size == 6) uni_6 = card2_0_4; else if (uni_size == 7) uni_7 = card2_0_4; else if (uni_size == 8) uni_8 = card2_0_4; else if (uni_size == 9) uni_9 = card2_0_4;
                        uni_size = uni_size + 1;
                    end
                end
                if (j == 1) begin
                    if (!is_in_array(card2_1_0, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card2_1_0; else if (uni_size == 1) uni_1 = card2_1_0; else if (uni_size == 2) uni_2 = card2_1_0; else if (uni_size == 3) uni_3 = card2_1_0; else if (uni_size == 4) uni_4 = card2_1_0; else if (uni_size == 5) uni_5 = card2_1_0; else if (uni_size == 6) uni_6 = card2_1_0; else if (uni_size == 7) uni_7 = card2_1_0; else if (uni_size == 8) uni_8 = card2_1_0; else if (uni_size == 9) uni_9 = card2_1_0;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card2_1_1, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card2_1_1; else if (uni_size == 1) uni_1 = card2_1_1; else if (uni_size == 2) uni_2 = card2_1_1; else if (uni_size == 3) uni_3 = card2_1_1; else if (uni_size == 4) uni_4 = card2_1_1; else if (uni_size == 5) uni_5 = card2_1_1; else if (uni_size == 6) uni_6 = card2_1_1; else if (uni_size == 7) uni_7 = card2_1_1; else if (uni_size == 8) uni_8 = card2_1_1; else if (uni_size == 9) uni_9 = card2_1_1;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card2_1_2, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card2_1_2; else if (uni_size == 1) uni_1 = card2_1_2; else if (uni_size == 2) uni_2 = card2_1_2; else if (uni_size == 3) uni_3 = card2_1_2; else if (uni_size == 4) uni_4 = card2_1_2; else if (uni_size == 5) uni_5 = card2_1_2; else if (uni_size == 6) uni_6 = card2_1_2; else if (uni_size == 7) uni_7 = card2_1_2; else if (uni_size == 8) uni_8 = card2_1_2; else if (uni_size == 9) uni_9 = card2_1_2;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card2_1_3, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card2_1_3; else if (uni_size == 1) uni_1 = card2_1_3; else if (uni_size == 2) uni_2 = card2_1_3; else if (uni_size == 3) uni_3 = card2_1_3; else if (uni_size == 4) uni_4 = card2_1_3; else if (uni_size == 5) uni_5 = card2_1_3; else if (uni_size == 6) uni_6 = card2_1_3; else if (uni_size == 7) uni_7 = card2_1_3; else if (uni_size == 8) uni_8 = card2_1_3; else if (uni_size == 9) uni_9 = card2_1_3;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card2_1_4, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card2_1_4; else if (uni_size == 1) uni_1 = card2_1_4; else if (uni_size == 2) uni_2 = card2_1_4; else if (uni_size == 3) uni_3 = card2_1_4; else if (uni_size == 4) uni_4 = card2_1_4; else if (uni_size == 5) uni_5 = card2_1_4; else if (uni_size == 6) uni_6 = card2_1_4; else if (uni_size == 7) uni_7 = card2_1_4; else if (uni_size == 8) uni_8 = card2_1_4; else if (uni_size == 9) uni_9 = card2_1_4;
                        uni_size = uni_size + 1;
                    end
                end
                if (j == 2) begin
                    if (!is_in_array(card2_2_0, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card2_2_0; else if (uni_size == 1) uni_1 = card2_2_0; else if (uni_size == 2) uni_2 = card2_2_0; else if (uni_size == 3) uni_3 = card2_2_0; else if (uni_size == 4) uni_4 = card2_2_0; else if (uni_size == 5) uni_5 = card2_2_0; else if (uni_size == 6) uni_6 = card2_2_0; else if (uni_size == 7) uni_7 = card2_2_0; else if (uni_size == 8) uni_8 = card2_2_0; else if (uni_size == 9) uni_9 = card2_2_0;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card2_2_1, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card2_2_1; else if (uni_size == 1) uni_1 = card2_2_1; else if (uni_size == 2) uni_2 = card2_2_1; else if (uni_size == 3) uni_3 = card2_2_1; else if (uni_size == 4) uni_4 = card2_2_1; else if (uni_size == 5) uni_5 = card2_2_1; else if (uni_size == 6) uni_6 = card2_2_1; else if (uni_size == 7) uni_7 = card2_2_1; else if (uni_size == 8) uni_8 = card2_2_1; else if (uni_size == 9) uni_9 = card2_2_1;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card2_2_2, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card2_2_2; else if (uni_size == 1) uni_1 = card2_2_2; else if (uni_size == 2) uni_2 = card2_2_2; else if (uni_size == 3) uni_3 = card2_2_2; else if (uni_size == 4) uni_4 = card2_2_2; else if (uni_size == 5) uni_5 = card2_2_2; else if (uni_size == 6) uni_6 = card2_2_2; else if (uni_size == 7) uni_7 = card2_2_2; else if (uni_size == 8) uni_8 = card2_2_2; else if (uni_size == 9) uni_9 = card2_2_2;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card2_2_3, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card2_2_3; else if (uni_size == 1) uni_1 = card2_2_3; else if (uni_size == 2) uni_2 = card2_2_3; else if (uni_size == 3) uni_3 = card2_2_3; else if (uni_size == 4) uni_4 = card2_2_3; else if (uni_size == 5) uni_5 = card2_2_3; else if (uni_size == 6) uni_6 = card2_2_3; else if (uni_size == 7) uni_7 = card2_2_3; else if (uni_size == 8) uni_8 = card2_2_3; else if (uni_size == 9) uni_9 = card2_2_3;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card2_2_4, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card2_2_4; else if (uni_size == 1) uni_1 = card2_2_4; else if (uni_size == 2) uni_2 = card2_2_4; else if (uni_size == 3) uni_3 = card2_2_4; else if (uni_size == 4) uni_4 = card2_2_4; else if (uni_size == 5) uni_5 = card2_2_4; else if (uni_size == 6) uni_6 = card2_2_4; else if (uni_size == 7) uni_7 = card2_2_4; else if (uni_size == 8) uni_8 = card2_2_4; else if (uni_size == 9) uni_9 = card2_2_4;
                        uni_size = uni_size + 1;
                    end
                end
                if (j == 3) begin
                    if (!is_in_array(card2_3_0, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card2_3_0; else if (uni_size == 1) uni_1 = card2_3_0; else if (uni_size == 2) uni_2 = card2_3_0; else if (uni_size == 3) uni_3 = card2_3_0; else if (uni_size == 4) uni_4 = card2_3_0; else if (uni_size == 5) uni_5 = card2_3_0; else if (uni_size == 6) uni_6 = card2_3_0; else if (uni_size == 7) uni_7 = card2_3_0; else if (uni_size == 8) uni_8 = card2_3_0; else if (uni_size == 9) uni_9 = card2_3_0;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card2_3_1, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card2_3_1; else if (uni_size == 1) uni_1 = card2_3_1; else if (uni_size == 2) uni_2 = card2_3_1; else if (uni_size == 3) uni_3 = card2_3_1; else if (uni_size == 4) uni_4 = card2_3_1; else if (uni_size == 5) uni_5 = card2_3_1; else if (uni_size == 6) uni_6 = card2_3_1; else if (uni_size == 7) uni_7 = card2_3_1; else if (uni_size == 8) uni_8 = card2_3_1; else if (uni_size == 9) uni_9 = card2_3_1;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card2_3_2, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card2_3_2; else if (uni_size == 1) uni_1 = card2_3_2; else if (uni_size == 2) uni_2 = card2_3_2; else if (uni_size == 3) uni_3 = card2_3_2; else if (uni_size == 4) uni_4 = card2_3_2; else if (uni_size == 5) uni_5 = card2_3_2; else if (uni_size == 6) uni_6 = card2_3_2; else if (uni_size == 7) uni_7 = card2_3_2; else if (uni_size == 8) uni_8 = card2_3_2; else if (uni_size == 9) uni_9 = card2_3_2;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card2_3_3, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card2_3_3; else if (uni_size == 1) uni_1 = card2_3_3; else if (uni_size == 2) uni_2 = card2_3_3; else if (uni_size == 3) uni_3 = card2_3_3; else if (uni_size == 4) uni_4 = card2_3_3; else if (uni_size == 5) uni_5 = card2_3_3; else if (uni_size == 6) uni_6 = card2_3_3; else if (uni_size == 7) uni_7 = card2_3_3; else if (uni_size == 8) uni_8 = card2_3_3; else if (uni_size == 9) uni_9 = card2_3_3;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card2_3_4, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card2_3_4; else if (uni_size == 1) uni_1 = card2_3_4; else if (uni_size == 2) uni_2 = card2_3_4; else if (uni_size == 3) uni_3 = card2_3_4; else if (uni_size == 4) uni_4 = card2_3_4; else if (uni_size == 5) uni_5 = card2_3_4; else if (uni_size == 6) uni_6 = card2_3_4; else if (uni_size == 7) uni_7 = card2_3_4; else if (uni_size == 8) uni_8 = card2_3_4; else if (uni_size == 9) uni_9 = card2_3_4;
                        uni_size = uni_size + 1;
                    end
                end
                if (j == 4) begin
                    if (!is_in_array(card2_4_0, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card2_4_0; else if (uni_size == 1) uni_1 = card2_4_0; else if (uni_size == 2) uni_2 = card2_4_0; else if (uni_size == 3) uni_3 = card2_4_0; else if (uni_size == 4) uni_4 = card2_4_0; else if (uni_size == 5) uni_5 = card2_4_0; else if (uni_size == 6) uni_6 = card2_4_0; else if (uni_size == 7) uni_7 = card2_4_0; else if (uni_size == 8) uni_8 = card2_4_0; else if (uni_size == 9) uni_9 = card2_4_0;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card2_4_1, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card2_4_1; else if (uni_size == 1) uni_1 = card2_4_1; else if (uni_size == 2) uni_2 = card2_4_1; else if (uni_size == 3) uni_3 = card2_4_1; else if (uni_size == 4) uni_4 = card2_4_1; else if (uni_size == 5) uni_5 = card2_4_1; else if (uni_size == 6) uni_6 = card2_4_1; else if (uni_size == 7) uni_7 = card2_4_1; else if (uni_size == 8) uni_8 = card2_4_1; else if (uni_size == 9) uni_9 = card2_4_1;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card2_4_2, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card2_4_2; else if (uni_size == 1) uni_1 = card2_4_2; else if (uni_size == 2) uni_2 = card2_4_2; else if (uni_size == 3) uni_3 = card2_4_2; else if (uni_size == 4) uni_4 = card2_4_2; else if (uni_size == 5) uni_5 = card2_4_2; else if (uni_size == 6) uni_6 = card2_4_2; else if (uni_size == 7) uni_7 = card2_4_2; else if (uni_size == 8) uni_8 = card2_4_2; else if (uni_size == 9) uni_9 = card2_4_2;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card2_4_3, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card2_4_3; else if (uni_size == 1) uni_1 = card2_4_3; else if (uni_size == 2) uni_2 = card2_4_3; else if (uni_size == 3) uni_3 = card2_4_3; else if (uni_size == 4) uni_4 = card2_4_3; else if (uni_size == 5) uni_5 = card2_4_3; else if (uni_size == 6) uni_6 = card2_4_3; else if (uni_size == 7) uni_7 = card2_4_3; else if (uni_size == 8) uni_8 = card2_4_3; else if (uni_size == 9) uni_9 = card2_4_3;
                        uni_size = uni_size + 1;
                    end
                    if (!is_in_array(card2_4_4, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size) && uni_size < MAX_UNION_SIZE) begin
                        if (uni_size == 0) uni_0 = card2_4_4; else if (uni_size == 1) uni_1 = card2_4_4; else if (uni_size == 2) uni_2 = card2_4_4; else if (uni_size == 3) uni_3 = card2_4_4; else if (uni_size == 4) uni_4 = card2_4_4; else if (uni_size == 5) uni_5 = card2_4_4; else if (uni_size == 6) uni_6 = card2_4_4; else if (uni_size == 7) uni_7 = card2_4_4; else if (uni_size == 8) uni_8 = card2_4_4; else if (uni_size == 9) uni_9 = card2_4_4;
                        uni_size = uni_size + 1;
                    end
                end

                // For each element in intersection, check if it can be the last number
                for (int x_idx = 0; x_idx < inter_size; x_idx = x_idx + 1) begin
                    reg [DATA_WIDTH-1:0] x;
                    if (x_idx == 0) x = inter_0; else if (x_idx == 1) x = inter_1; else if (x_idx == 2) x = inter_2; else if (x_idx == 3) x = inter_3; else if (x_idx == 4) x = inter_4;
                    int valid = 1;

                    // Check all rows in card1
                    for (int r = 0; r < ROWS; r = r + 1) begin
                        // Check if this row is subset of union
                        int is_subset = 1;
                        for (int c = 0; c < COLS; c = c + 1) begin
                            reg [DATA_WIDTH-1:0] elem;
                            if (r == 0 && c == 0) elem = card1_0_0; else if (r == 0 && c == 1) elem = card1_0_1; else if (r == 0 && c == 2) elem = card1_0_2; else if (r == 0 && c == 3) elem = card1_0_3; else if (r == 0 && c == 4) elem = card1_0_4;
                            else if (r == 1 && c == 0) elem = card1_1_0; else if (r == 1 && c == 1) elem = card1_1_1; else if (r == 1 && c == 2) elem = card1_1_2; else if (r == 1 && c == 3) elem = card1_1_3; else if (r == 1 && c == 4) elem = card1_1_4;
                            else if (r == 2 && c == 0) elem = card1_2_0; else if (r == 2 && c == 1) elem = card1_2_1; else if (r == 2 && c == 2) elem = card1_2_2; else if (r == 2 && c == 3) elem = card1_2_3; else if (r == 2 && c == 4) elem = card1_2_4;
                            else if (r == 3 && c == 0) elem = card1_3_0; else if (r == 3 && c == 1) elem = card1_3_1; else if (r == 3 && c == 2) elem = card1_3_2; else if (r == 3 && c == 3) elem = card1_3_3; else if (r == 3 && c == 4) elem = card1_3_4;
                            else if (r == 4 && c == 0) elem = card1_4_0; else if (r == 4 && c == 1) elem = card1_4_1; else if (r == 4 && c == 2) elem = card1_4_2; else if (r == 4 && c == 3) elem = card1_4_3; else if (r == 4 && c == 4) elem = card1_4_4;
                            if (!is_in_array(elem, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size)) begin
                                is_subset = 0;
                            end
                        end
                        if (is_subset) begin
                            // If subset, must contain x
                            int contains_x = 0;
                            for (int c = 0; c < COLS; c = c + 1) begin
                                reg [DATA_WIDTH-1:0] elem;
                                if (r == 0 && c == 0) elem = card1_0_0; else if (r == 0 && c == 1) elem = card1_0_1; else if (r == 0 && c == 2) elem = card1_0_2; else if (r == 0 && c == 3) elem = card1_0_3; else if (r == 0 && c == 4) elem = card1_0_4;
                                else if (r == 1 && c == 0) elem = card1_1_0; else if (r == 1 && c == 1) elem = card1_1_1; else if (r == 1 && c == 2) elem = card1_1_2; else if (r == 1 && c == 3) elem = card1_1_3; else if (r == 1 && c == 4) elem = card1_1_4;
                                else if (r == 2 && c == 0) elem = card1_2_0; else if (r == 2 && c == 1) elem = card1_2_1; else if (r == 2 && c == 2) elem = card1_2_2; else if (r == 2 && c == 3) elem = card1_2_3; else if (r == 2 && c == 4) elem = card1_2_4;
                                else if (r == 3 && c == 0) elem = card1_3_0; else if (r == 3 && c == 1) elem = card1_3_1; else if (r == 3 && c == 2) elem = card1_3_2; else if (r == 3 && c == 3) elem = card1_3_3; else if (r == 3 && c == 4) elem = card1_3_4;
                                else if (r == 4 && c == 0) elem = card1_4_0; else if (r == 4 && c == 1) elem = card1_4_1; else if (r == 4 && c == 2) elem = card1_4_2; else if (r == 4 && c == 3) elem = card1_4_3; else if (r == 4 && c == 4) elem = card1_4_4;
                                if (elem == x) contains_x = 1;
                            end
                            if (!contains_x) valid = 0;
                        end
                    end

                    // Check all rows in card2
                    for (int r = 0; r < ROWS; r = r + 1) begin
                        int is_subset = 1;
                        for (int c = 0; c < COLS; c = c + 1) begin
                            reg [DATA_WIDTH-1:0] elem;
                            if (r == 0 && c == 0) elem = card2_0_0; else if (r == 0 && c == 1) elem = card2_0_1; else if (r == 0 && c == 2) elem = card2_0_2; else if (r == 0 && c == 3) elem = card2_0_3; else if (r == 0 && c == 4) elem = card2_0_4;
                            else if (r == 1 && c == 0) elem = card2_1_0; else if (r == 1 && c == 1) elem = card2_1_1; else if (r == 1 && c == 2) elem = card2_1_2; else if (r == 1 && c == 3) elem = card2_1_3; else if (r == 1 && c == 4) elem = card2_1_4;
                            else if (r == 2 && c == 0) elem = card2_2_0; else if (r == 2 && c == 1) elem = card2_2_1; else if (r == 2 && c == 2) elem = card2_2_2; else if (r == 2 && c == 3) elem = card2_2_3; else if (r == 2 && c == 4) elem = card2_2_4;
                            else if (r == 3 && c == 0) elem = card2_3_0; else if (r == 3 && c == 1) elem = card2_3_1; else if (r == 3 && c == 2) elem = card2_3_2; else if (r == 3 && c == 3) elem = card2_3_3; else if (r == 3 && c == 4) elem = card2_3_4;
                            else if (r == 4 && c == 0) elem = card2_4_0; else if (r == 4 && c == 1) elem = card2_4_1; else if (r == 4 && c == 2) elem = card2_4_2; else if (r == 4 && c == 3) elem = card2_4_3; else if (r == 4 && c == 4) elem = card2_4_4;
                            if (!is_in_array(elem, uni_0, uni_1, uni_2, uni_3, uni_4, uni_5, uni_6, uni_7, uni_8, uni_9, uni_size)) begin
                                is_subset = 0;
                            end
                        end
                        if (is_subset) begin
                            int contains_x = 0;
                            for (int c = 0; c < COLS; c = c + 1) begin
                                reg [DATA_WIDTH-1:0] elem;
                                if (r == 0 && c == 0) elem = card2_0_0; else if (r == 0 && c == 1) elem = card2_0_1; else if (r == 0 && c == 2) elem = card2_0_2; else if (r == 0 && c == 3) elem = card2_0_3; else if (r == 0 && c == 4) elem = card2_0_4;
                                else if (r == 1 && c == 0) elem = card2_1_0; else if (r == 1 && c == 1) elem = card2_1_1; else if (r == 1 && c == 2) elem = card2_1_2; else if (r == 1 && c == 3) elem = card2_1_3; else if (r == 1 && c == 4) elem = card2_1_4;
                                else if (r == 2 && c == 0) elem = card2_2_0; else if (r == 2 && c == 1) elem = card2_2_1; else if (r == 2 && c == 2) elem = card2_2_2; else if (r == 2 && c == 3) elem = card2_2_3; else if (r == 2 && c == 4) elem = card2_2_4;
                                else if (r == 3 && c == 0) elem = card2_3_0; else if (r == 3 && c == 1) elem = card2_3_1; else if (r == 3 && c == 2) elem = card2_3_2; else if (r == 3 && c == 3) elem = card2_3_3; else if (r == 3 && c == 4) elem = card2_3_4;
                                else if (r == 4 && c == 0) elem = card2_4_0; else if (r == 4 && c == 1) elem = card2_4_1; else if (r == 4 && c == 2) elem = card2_4_2; else if (r == 4 && c == 3) elem = card2_4_3; else if (r == 4 && c == 4) elem = card2_4_4;
                                if (elem == x) contains_x = 1;
                            end
                            if (!contains_x) valid = 0;
                        end
                    end

                    if (valid) begin
                        tie_found = 1;
                        tie_row1 = i;
                        tie_row2 = j;
                    end
                end
                if (tie_found) break;
            end
            if (tie_found) break;
        end
    end
endmodule