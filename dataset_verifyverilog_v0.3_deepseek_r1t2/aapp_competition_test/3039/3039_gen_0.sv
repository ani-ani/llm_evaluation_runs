module can_fold (
    input wire [35:0] grid_flat,
    output reg can_fold
);

    // Extract coordinates of '#'
    integer row_addr [0:5];
    integer col_addr [0:5];
    integer count;
    integer i, j;
    always @(*) begin
        count = 0;
        for (i = 0; i < 6; i = i + 1) begin
            for (j = 0; j < 6; j = j + 1) begin
                if (grid_flat[i*6 + j]) begin
                    row_addr[count] = i;
                    col_addr[count] = j;
                    count = count + 1;
                end
            end
        end
    end

    // Normalize coordinates
    integer min_row, min_col;
    integer norm_row [0:5];
    integer norm_col [0:5];
    always @(*) begin
        min_row = row_addr[0];
        min_col = col_addr[0];
        for (i = 1; i < 6; i = i + 1) begin
            if (row_addr[i] < min_row) min_row = row_addr[i];
            if (col_addr[i] < min_col) min_col = col_addr[i];
        end
        for (i = 0; i < 6; i = i + 1) begin
            norm_row[i] = row_addr[i] - min_row;
            norm_col[i] = col_addr[i] - min_col;
        end
    end

    // Pattern ROM (88 valid cube nets)
    reg [35:0] rom [0:87];
    initial begin
        // SYNTHESIS MEMORY_INITIALIZATION HERE (omitted for brevity)
        rom[0] = 36'd0;  // Replace with actual net patterns
    end

    // Transformation and checking
    integer t;
    integer t_r_arr [0:5];
    integer t_c_arr [0:5];
    integer t_min_r, t_min_c;
    reg [35:0] pattern;
    integer rom_idx;

    always @(*) begin
        can_fold = 1'b0;
        if (count != 6) begin
            can_fold = 1'b0;
        end else begin
            // Try all 8 transformations
            for (t = 0; t < 8; t = t + 1) begin
                // Apply coordinate transformation
                for (i = 0; i < 6; i = i + 1) begin
                    case (t)
                        0: begin t_r_arr[i] = norm_row[i]; t_c_arr[i] = norm_col[i]; end
                        1: begin t_r_arr[i] = norm_col[i]; t_c_arr[i] = -norm_row[i]; end
                        2: begin t_r_arr[i] = -norm_row[i]; t_c_arr[i] = -norm_col[i]; end
                        3: begin t_r_arr[i] = -norm_col[i]; t_c_arr[i] = norm_row[i]; end
                        4: begin t_r_arr[i] = norm_row[i]; t_c_arr[i] = -norm_col[i]; end
                        5: begin t_r_arr[i] = -norm_row[i]; t_c_arr[i] = norm_col[i]; end
                        6: begin t_r_arr[i] = norm_col[i]; t_c_arr[i] = norm_row[i]; end
                        7: begin t_r_arr[i] = -norm_col[i]; t_c_arr[i] = -norm_row[i]; end
                        default: begin t_r_arr[i] = norm_row[i]; t_c_arr[i] = norm_col[i]; end
                    endcase
                end

                // Find new origin
                t_min_r = t_r_arr[0];
                t_min_c = t_c_arr[0];
                for (i = 1; i < 6; i = i + 1) begin
                    if (t_r_arr[i] < t_min_r) t_min_r = t_r_arr[i];
                    if (t_c_arr[i] < t_min_c) t_min_c = t_c_arr[i];
                end

                // Create transformed pattern
                pattern = 36'd0;
                for (i = 0; i < 6; i = i + 1) begin
                    t_r_arr[i] = t_r_arr[i] - t_min_r;
                    t_c_arr[i] = t_c_arr[i] - t_min_c;
                    if (t_r_arr[i] < 6 && t_c_arr[i] < 6) begin
                        pattern[t_r_arr[i]*6 + t_c_arr[i]] = 1'b1;
                    end
                end

                // Compare against all ROM patterns
                for (rom_idx = 0; rom_idx < 88; rom_idx = rom_idx + 1) begin
                    if (pattern == rom[rom_idx]) 
                        can_fold = 1'b1;
                end
            end
        end
    end
endmodule