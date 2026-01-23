module can_fold (
    input wire [35:0] grid_flat,
    output reg can_fold
);

    reg [5:0] row_addr [0:5];
    reg [5:0] col_addr [0:5];
    reg [5:0] count;
    integer i, j;

    always @(*) begin
        count = 6'd0;
        for (i = 0; i < 6; i = i + 1) begin
            for (j = 0; j < 6; j = j + 1) begin
                if (grid_flat[i*6 + j] == 1'b1) begin
                    row_addr[count] = i;
                    col_addr[count] = j;
                    count = count + 6'd1;
                end
            end
        end
    end

    reg [5:0] min_row, min_col;
    reg [5:0] norm_row [0:5];
    reg [5:0] norm_col [0:5];

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

    reg [35:0] rom [0:87];

    initial begin
        rom[0] = 36'h000000000;
        rom[1] = 36'h000000000;
        rom[2] = 36'h000000000;
        rom[3] = 36'h000000000;
        rom[4] = 36'h000000000;
        rom[5] = 36'h000000000;
        rom[6] = 36'h000000000;
        rom[7] = 36'h000000000;
        rom[8] = 36'h000000000;
        rom[9] = 36'h000000000;
        rom[10] = 36'h000000000;
        rom[11] = 36'h000000000;
        rom[12] = 36'h000000000;
        rom[13] = 36'h000000000;
        rom[14] = 36'h000000000;
        rom[15] = 36'h000000000;
        rom[16] = 36'h000000000;
        rom[17] = 36'h000000000;
        rom[18] = 36'h000000000;
        rom[19] = 36'h000000000;
        rom[20] = 36'h000000000;
        rom[21] = 36'h000000000;
        rom[22] = 36'h000000000;
        rom[23] = 36'h000000000;
        rom[24] = 36'h000000000;
        rom[25] = 36'h000000000;
        rom[26] = 36'h000000000;
        rom[27] = 36'h000000000;
        rom[28] = 36'h000000000;
        rom[29] = 36'h000000000;
        rom[30] = 36'h000000000;
        rom[31] = 36'h000000000;
        rom[32] = 36'h000000000;
        rom[33] = 36'h000000000;
        rom[34] = 36'h000000000;
        rom[35] = 36'h000000000;
        rom[36] = 36'h000000000;
        rom[37] = 36'h000000000;
        rom[38] = 36'h000000000;
        rom[39] = 36'h000000000;
        rom[40] = 36'h000000000;
        rom[41] = 36'h000000000;
        rom[42] = 36'h000000000;
        rom[43] = 36'h000000000;
        rom[44] = 36'h000000000;
        rom[45] = 36'h000000000;
        rom[46] = 36'h000000000;
        rom[47] = 36'h000000000;
        rom[48] = 36'h000000000;
        rom[49] = 36'h000000000;
        rom[50] = 36'h000000000;
        rom[51] = 36'h000000000;
        rom[52] = 36'h000000000;
        rom[53] = 36'h000000000;
        rom[54] = 36'h000000000;
        rom[55] = 36'h000000000;
        rom[56] = 36'h000000000;
        rom[57] = 36'h000000000;
        rom[58] = 36'h000000000;
        rom[59] = 36'h000000000;
        rom[60] = 36'h000000000;
        rom[61] = 36'h000000000;
        rom[62] = 36'h000000000;
        rom[63] = 36'h000000000;
        rom[64] = 36'h000000000;
        rom[65] = 36'h000000000;
        rom[66] = 36'h000000000;
        rom[67] = 36'h000000000;
        rom[68] = 36'h000000000;
        rom[69] = 36'h000000000;
        rom[70] = 36'h000000000;
        rom[71] = 36'h000000000;
        rom[72] = 36'h000000000;
        rom[73] = 36'h000000000;
        rom[74] = 36'h000000000;
        rom[75] = 36'h000000000;
        rom[76] = 36'h000000000;
        rom[77] = 36'h000000000;
        rom[78] = 36'h000000000;
        rom[79] = 36'h000000000;
        rom[80] = 36'h000000000;
        rom[81] = 36'h000000000;
        rom[82] = 36'h000000000;
        rom[83] = 36'h000000000;
        rom[84] = 36'h000000000;
        rom[85] = 36'h000000000;
        rom[86] = 36'h000000000;
        rom[87] = 36'h000000000;
    end

    reg [5:0] t_r_arr [0:5];
    reg [5:0] t_c_arr [0:5];
    reg [5:0] t_min_r, t_min_c;
    reg [35:0] pattern;
    integer t, rom_idx;

    always @(*) begin
        can_fold = 1'b0;
        if (count != 6'd6) begin
            can_fold = 1'b0;
        end else begin
            for (t = 0; t < 8; t = t + 1) begin
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
                    endcase
                end

                t_min_r = t_r_arr[0];
                t_min_c = t_c_arr[0];
                for (i = 1; i < 6; i = i + 1) begin
                    if (t_r_arr[i] < t_min_r) t_min_r = t_r_arr[i];
                    if (t_c_arr[i] < t_min_c) t_min_c = t_c_arr[i];
                end

                pattern = 36'd0;
                for (i = 0; i < 6; i = i + 1) begin
                    t_r_arr[i] = t_r_arr[i] - t_min_r;
                    t_c_arr[i] = t_c_arr[i] - t_min_c;
                    if (t_r_arr[i] >= 0 && t_r_arr[i] < 6 && t_c_arr[i] >= 0 && t_c_arr[i] < 6) begin
                        pattern[t_r_arr[i]*6 + t_c_arr[i]] = 1'b1;
                    end
                end

                for (rom_idx = 0; rom_idx < 88; rom_idx = rom_idx + 1) begin
                    if (pattern == rom[rom_idx]) begin
                        can_fold = 1'b1;
                    end
                end
            end
        end
    end
endmodule