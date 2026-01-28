module BingoTwoCardChecker (
    input [11:0] card1 [0:4][0:4],
    input [11:0] card2 [0:4][0:4],
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

    // Internal helper: check if num is in array arr of size size
    // Since unpacked arrays can't be passed as arguments, we inline logic

    // Main combinational logic
    always_comb begin
        // Initialize outputs
        tie_found = 1'b0;
        tie_row1 = 3'd0;
        tie_row2 = 3'd0;

        // Iterate over each row in card1
        for (int i = 0; i < ROWS; i = i + 1) begin
            // Iterate over each row in card2
            for (int j = 0; j < ROWS; j = j + 1) begin
                // Skip if tie already found
                if (!tie_found) begin
                    // Compute intersection of row i and row j
                    reg [DATA_WIDTH-1:0] inter [0:MAX_INTERSECTION_SIZE-1];
                    int inter_size = 0;
                    
                    // Find intersection
                    for (int k = 0; k < COLS; k = k + 1) begin
                        for (int l = 0; l < COLS; l = l + 1) begin
                            if (card1[i][k] == card2[j][l]) begin
                                // Check if already in intersection
                                int found_in_inter = 0;
                                for (int m = 0; m < inter_size; m = m + 1) begin
                                    if (inter[m] == card1[i][k]) begin
                                        found_in_inter = 1;
                                    end
                                end
                                if (!found_in_inter && inter_size < MAX_INTERSECTION_SIZE) begin
                                    inter[inter_size] = card1[i][k];
                                    inter_size = inter_size + 1;
                                end
                            end
                        end
                    end

                    // Compute union of row i and row j
                    reg [DATA_WIDTH-1:0] uni [0:MAX_UNION_SIZE-1];
                    int uni_size = 0;
                    
                    // Add all from row i
                    for (int k = 0; k < COLS; k = k + 1) begin
                        int found_in_uni = 0;
                        for (int m = 0; m < uni_size; m = m + 1) begin
                            if (uni[m] == card1[i][k]) begin
                                found_in_uni = 1;
                            end
                        end
                        if (!found_in_uni && uni_size < MAX_UNION_SIZE) begin
                            uni[uni_size] = card1[i][k];
                            uni_size = uni_size + 1;
                        end
                    end
                    // Add all from row j
                    for (int k = 0; k < COLS; k = k + 1) begin
                        int found_in_uni = 0;
                        for (int m = 0; m < uni_size; m = m + 1) begin
                            if (uni[m] == card2[j][k]) begin
                                found_in_uni = 1;
                            end
                        end
                        if (!found_in_uni && uni_size < MAX_UNION_SIZE) begin
                            uni[uni_size] = card2[j][k];
                            uni_size = uni_size + 1;
                        end
                    end

                    // For each element in intersection, check if it can be the last number
                    for (int x_idx = 0; x_idx < inter_size; x_idx = x_idx + 1) begin
                        reg [DATA_WIDTH-1:0] x;
                        int valid;
                        
                        x = inter[x_idx];
                        valid = 1;

                        // Check all rows in card1
                        for (int r = 0; r < ROWS && valid; r = r + 1) begin
                            // Check if this row is subset of union
                            int is_subset = 1;
                            for (int c = 0; c < COLS && is_subset; c = c + 1) begin
                                int found_in_uni = 0;
                                for (int m = 0; m < uni_size; m = m + 1) begin
                                    if (uni[m] == card1[r][c]) begin
                                        found_in_uni = 1;
                                    end
                                end
                                if (!found_in_uni) begin
                                    is_subset = 0;
                                end
                            end
                            
                            if (is_subset) begin
                                // If subset, must contain x
                                int contains_x = 0;
                                for (int c = 0; c < COLS; c = c + 1) begin
                                    if (card1[r][c] == x) begin
                                        contains_x = 1;
                                    end
                                end
                                if (!contains_x) begin
                                    valid = 0;
                                end
                            end
                        end

                        // Check all rows in card2
                        for (int r = 0; r < ROWS && valid; r = r + 1) begin
                            // Check if this row is subset of union
                            int is_subset = 1;
                            for (int c = 0; c < COLS && is_subset; c = c + 1) begin
                                int found_in_uni = 0;
                                for (int m = 0; m < uni_size; m = m + 1) begin
                                    if (uni[m] == card2[r][c]) begin
                                        found_in_uni = 1;
                                    end
                                end
                                if (!found_in_uni) begin
                                    is_subset = 0;
                                end
                            end
                            
                            if (is_subset) begin
                                // If subset, must contain x
                                int contains_x = 0;
                                for (int c = 0; c < COLS; c = c + 1) begin
                                    if (card2[r][c] == x) begin
                                        contains_x = 1;
                                    end
                                end
                                if (!contains_x) begin
                                    valid = 0;
                                end
                            end
                        end

                        if (valid && !tie_found) begin
                            tie_found = 1'b1;
                            tie_row1 = i[2:0];
                            tie_row2 = j[2:0];
                        end
                    end
                end
            end
        end
    end
endmodule