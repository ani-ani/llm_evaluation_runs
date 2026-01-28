module find_squares_3x3 (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] grid_row0,
    input wire [2:0] grid_row1,
    input wire [2:0] grid_row2,
    output reg [1:0] square1_row,
    output reg [1:0] square1_col,
    output reg [1:0] square1_size,
    output reg [1:0] square2_row,
    output reg [1:0] square2_col,
    output reg [1:0] square2_size,
    output reg done
);

    // State encoding
    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] PRECOMPUTE = 2'b01;
    localparam [1:0] SEARCH = 2'b10;
    localparam [1:0] DONE = 2'b11;

    reg [1:0] state, next_state;
    reg [8:0] x_mask_reg;
    reg [13:0] valid;
    reg [3:0] i_reg, j_reg;
    reg [3:0] search_i_reg, search_j_reg;
    reg found;
    wire [8:0] combined_mask;

    // Combinational logic for combined mask
    function [8:0] get_mask;
        input [3:0] idx;
        begin
            case (idx)
                0: get_mask = 9'b000000001;
                1: get_mask = 9'b000011011;
                2: get_mask = 9'b111111111;
                3: get_mask = 9'b000000010;
                4: get_mask = 9'b000110110;
                5: get_mask = 9'b000000100;
                6: get_mask = 9'b000001000;
                7: get_mask = 9'b011011000;
                8: get_mask = 9'b000010000;
                9: get_mask = 9'b110110000;
                10: get_mask = 9'b000100000;
                11: get_mask = 9'b001000000;
                12: get_mask = 9'b010000000;
                13: get_mask = 9'b100000000;
                default: get_mask = 9'b0;
            endcase
        end
    endfunction

    assign combined_mask = get_mask(search_i_reg) | get_mask(search_j_reg);

    function [1:0] get_row;
        input [3:0] idx;
        begin
            case (idx)
                0,1,2,3,4,5: get_row = 2'b00;
                6,7,8,9,10: get_row = 2'b01;
                11,12,13: get_row = 2'b10;
                default: get_row = 2'b00;
            endcase
        end
    endfunction

    function [1:0] get_col;
        input [3:0] idx;
        begin
            case (idx)
                0,1,2,6,7,11: get_col = 2'b00;
                3,4,8,9,12: get_col = 2'b01;
                5,10,13: get_col = 2'b10;
                default: get_col = 2'b00;
            endcase
        end
    endfunction

    function [1:0] get_size;
        input [3:0] idx;
        begin
            case (idx)
                0,3,5,6,8,10,11,12,13: get_size = 2'b01;
                1,4,7,9: get_size = 2'b10;
                2: get_size = 2'b11;
                default: get_size = 2'b00;
            endcase
        end
    endfunction

    function [13:0] compute_valid;
        input [8:0] x_mask;
        integer k;
        begin
            compute_valid = 14'b0;
            for (k = 0; k < 14; k = k + 1) begin
                if ((get_mask(k) & x_mask) == get_mask(k)) begin
                    compute_valid[k] = 1'b1;
                end
            end
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            valid <= 14'b0;
            x_mask_reg <= 9'b0;
            square1_row <= 2'b0;
            square1_col <= 2'b0;
            square1_size <= 2'b0;
            square2_row <= 2'b0;
            square2_col <= 2'b0;
            square2_size <= 2'b0;
            found <= 1'b0;
            search_i_reg <= 4'd0;
            search_j_reg <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    found <= 1'b0;
                    search_i_reg <= 4'd0;
                    search_j_reg <= 4'd1;
                    if (start) begin
                        state <= PRECOMPUTE;
                    end
                end

                PRECOMPUTE: begin
                    x_mask_reg <= {grid_row2, grid_row1, grid_row0};
                    valid <= compute_valid({grid_row2, grid_row1, grid_row0});
                    state <= SEARCH;
                    search_i_reg <= 4'd0;
                    search_j_reg <= 4'd1;
                end

                SEARCH: begin
                    if (!found) begin
                        if (search_i_reg < 14 && search_j_reg < 14) begin
                            if (valid[search_i_reg] && valid[search_j_reg]) begin
                                if (combined_mask == x_mask_reg) begin
                                    square1_row <= get_row(search_i_reg);
                                    square1_col <= get_col(search_i_reg);
                                    square1_size <= get_size(search_i_reg);
                                    square2_row <= get_row(search_j_reg);
                                    square2_col <= get_col(search_j_reg);
                                    square2_size <= get_size(search_j_reg);
                                    found <= 1'b1;
                                end
                            end
                            if (search_j_reg == 4'd13) begin
                                search_j_reg <= search_i_reg + 4'd1;
                                search_i_reg <= search_i_reg + 4'd1;
                            end else begin
                                search_j_reg <= search_j_reg + 4'd1;
                            end
                        end else begin
                            done <= 1'b1;
                            state <= DONE;
                        end
                        if (found) begin
                            done <= 1'b1;
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule