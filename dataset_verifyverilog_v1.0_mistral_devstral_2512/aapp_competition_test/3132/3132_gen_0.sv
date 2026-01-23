module find_squares_3x3 (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] grid_row0,  // row 0 (top)
    input wire [2:0] grid_row1,  // row 1
    input wire [2:0] grid_row2,  // row 2 (bottom)
    output reg [1:0] square1_row,
    output reg [1:0] square1_col,
    output reg [1:0] square1_size,
    output reg [1:0] square2_row,
    output reg [1:0] square2_col,
    output reg [1:0] square2_size,
    output reg done
);

// State encoding
localparam [1:0] IDLE = 2'd0;
localparam [1:0] PRECOMPUTE = 2'd1;
localparam [1:0] SEARCH = 2'd2;
localparam [1:0] DONE = 2'd3;

reg [1:0] state;
reg [8:0] x_mask_reg; // 9-bit mask of all x cells
reg [13:0] valid; // valid flags for 14 squares
reg [3:0] i_reg, j_reg; // counters for pair search

// Function to get mask for each square index (0-13)
function [8:0] get_mask;
    input [3:0] idx;
    begin
        case (idx)
            0: get_mask = 9'b000000001; // (0,0) s=1
            1: get_mask = 9'b000011011; // (0,0) s=2
            2: get_mask = 9'b111111111; // (0,0) s=3
            3: get_mask = 9'b000000010; // (0,1) s=1
            4: get_mask = 9'b000110110; // (0,1) s=2
            5: get_mask = 9'b000000100; // (0,2) s=1
            6: get_mask = 9'b000001000; // (1,0) s=1
            7: get_mask = 9'b011011000; // (1,0) s=2
            8: get_mask = 9'b000010000; // (1,1) s=1
            9: get_mask = 9'b110110000; // (1,1) s=2
            10: get_mask = 9'b000100000; // (1,2) s=1
            11: get_mask = 9'b001000000; // (2,0) s=1
            12: get_mask = 9'b010000000; // (2,1) s=1
            13: get_mask = 9'b100000000; // (2,2) s=1
            default: get_mask = 9'b0;
        endcase
    end
endfunction

// Function to get row for each square index
function [1:0] get_row;
    input [3:0] idx;
    begin
        case (idx)
            0,1,2,3,4,5: get_row = 2'd0; // row 0
            6,7,8,9,10: get_row = 2'd1; // row 1
            11,12,13: get_row = 2'd2; // row 2
            default: get_row = 2'd0;
        endcase
    end
endfunction

// Function to get col for each square index
function [1:0] get_col;
    input [3:0] idx;
    begin
        case (idx)
            0,1,2,6,7,11: get_col = 2'd0; // col 0
            3,4,8,9,12: get_col = 2'd1; // col 1
            5,10,13: get_col = 2'd2; // col 2
            default: get_col = 2'd0;
        endcase
    end
endfunction

// Function to get size for each square index
function [1:0] get_size;
    input [3:0] idx;
    begin
        case (idx)
            0,3,5,6,8,10,11,12,13: get_size = 2'd1; // size 1
            1,4,7,9: get_size = 2'd2; // size 2
            2: get_size = 2'd3; // size 3
            default: get_size = 2'd0;
        endcase
    end
endfunction

// Combinational logic for combined mask
wire [8:0] combined_mask = get_mask(i_reg) | get_mask(j_reg);

// Function to compute valid flags
function [13:0] compute_valid;
    input [8:0] x_mask;
    integer i;
    begin
        compute_valid = 14'b0;
        for (i = 0; i < 14; i = i + 1) begin
            if ((get_mask(i) & x_mask) == get_mask(i)) begin
                compute_valid[i] = 1'b1;
            end
        end
    end
endfunction

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        i_reg <= 4'd0;
        j_reg <= 4'd0;
        valid <= 14'b0;
        x_mask_reg <= 9'b0;
        square1_row <= 2'd0;
        square1_col <= 2'd0;
        square1_size <= 2'd0;
        square2_row <= 2'd0;
        square2_col <= 2'd0;
        square2_size <= 2'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= PRECOMPUTE;
                end
            end

            PRECOMPUTE: begin
                x_mask_reg <= {grid_row2, grid_row1, grid_row0};
                valid <= compute_valid({grid_row2, grid_row1, grid_row0});
                state <= SEARCH;
                i_reg <= 4'd0;
                j_reg <= 4'd0;
            end

            SEARCH: begin
                if (i_reg < 14 && j_reg < 14) begin
                    if (valid[i_reg] && valid[j_reg]) begin
                        if (combined_mask == x_mask_reg) begin
                            square1_row <= get_row(i_reg);
                            square1_col <= get_col(i_reg);
                            square1_size <= get_size(i_reg);
                            square2_row <= get_row(j_reg);
                            square2_col <= get_col(j_reg);
                            square2_size <= get_size(j_reg);
                            done <= 1'b1;
                            state <= DONE;
                        end else begin
                            // Increment j
                            if (j_reg == 13) begin
                                j_reg <= i_reg + 1;
                                i_reg <= i_reg + 1;
                            end else begin
                                j_reg <= j_reg + 1;
                            end
                        end
                    end else begin
                        // Increment j
                        if (j_reg == 13) begin
                            j_reg <= i_reg + 1;
                            i_reg <= i_reg + 1;
                        end else begin
                            j_reg <= j_reg + 1;
                        end
                    end
                end else begin
                    // No solution found (should not happen)
                    done <= 1'b1;
                    state <= DONE;
                    square1_row <= 2'd0;
                    square1_col <= 2'd0;
                    square1_size <= 2'd0;
                    square2_row <= 2'd0;
                    square2_col <= 2'd0;
                    square2_size <= 2'd0;
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