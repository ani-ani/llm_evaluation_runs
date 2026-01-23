module treasure_map_solver (
    input [7:0] p1_data, p2_data, p3_data, p4_data,
    input [1:0] config,
    output reg [31:0] map_out,
    output reg valid
);

// Determine pieces for each quadrant based on config
wire [7:0] tl_piece, tr_piece, bl_piece, br_piece;

always @(*) begin
    case (config)
        2'b00: tl_piece = p1_data; tr_piece = p2_data; bl_piece = p3_data; br_piece = p4_data;
        2'b01: tl_piece = p1_data; tr_piece = p3_data; bl_piece = p2_data; br_piece = p4_data;
        2'b10: tl_piece = p2_data; tr_piece = p1_data; bl_piece = p3_data; br_piece = p4_data;
        2'b11: tl_piece = p2_data; tr_piece = p4_data; bl_piece = p1_data; br_piece = p3_data;
    endcase
end

// Define wires for each cell's 2-bit value
wire [1:0] cell00, cell01, cell02, cell03,
        cell10, cell11, cell12, cell13,
        cell20, cell21, cell22, cell23,
        cell30, cell31, cell32, cell33;

// Assign each cell's value based on quadrant and piece
always @(*) begin
    // TL quadrant
    cell00 = tl_piece[1:0];
    cell01 = tl_piece[3:2];
    cell10 = tl_piece[5:4];
    cell11 = tl_piece[7:6];

    // TR quadrant
    cell02 = tr_piece[1:0];
    cell03 = tr_piece[3:2];
    cell12 = tr_piece[5:4];
    cell13 = tr_piece[7:6];

    // BL quadrant
    cell20 = bl_piece[1:0];
    cell21 = bl_piece[3:2];
    cell30 = bl_piece[5:4];
    cell31 = bl_piece[7:6];

    // BR quadrant
    cell22 = br_piece[1:0];
    cell23 = br_piece[3:2];
    cell32 = br_piece[5:4];
    cell33 = br_piece[7:6];
end

// Compute map_out
assign map_out = 
    cell00 << 0 | 
    cell01 << 2 | 
    cell02 << 4 | 
    cell03 << 6 | 
    cell10 << 8 | 
    cell11 <<10 | 
    cell12 <<12 | 
    cell13 <<14 | 
    cell20 <<16 | 
    cell21 <<18 | 
    cell22 <<20 | 
    cell23 <<22 | 
    cell30 <<24 | 
    cell31 <<26 | 
    cell32 <<28 | 
    cell33 <<30;

// Compute zero_count
wire zero_count;
assign zero_count = 
    (cell00 ==0) + (cell01 ==0) + (cell02 ==0) + (cell03 ==0) + 
    (cell10 ==0) + (cell11 ==0) + (cell12 ==0) + (cell13 ==0) + 
    (cell20 ==0) + (cell21 ==0) + (cell22 ==0) + (cell23 ==0) + 
    (cell30 ==0) + (cell31 ==0) + (cell32 ==0) + (cell33 ==0);

// Compute tx and ty
wire [1:0] tx, ty;

assign tx = 
    (cell00 ==0) ? 2'b00 : 
    (cell01 ==0) ? 2'b00 : 
    (cell02 ==0) ? 2'b00 : 
    (cell03 ==0) ? 2'b00 : 
    (cell10 ==0) ? 2'b01 : 
    (cell11 ==0) ? 2'b01 : 
    (cell12 ==0) ? 2'b01 : 
    (cell13 ==0) ? 2'b01 : 
    (cell20 ==0) ? 2'b10 : 
    (cell21 ==0) ? 2'b10 : 
    (cell22 ==0) ? 2'b10 : 
    (cell23 ==0) ? 2'b10 : 
    (cell30 ==0) ? 2'b11 : 
    (cell31 ==0) ? 2'b11 : 
    (cell32 ==0) ? 2'b11 : 
    (cell33 ==0) ? 2'b11 : 2'bxx;

assign ty = 
    (cell00 ==0) ? 2'b00 : 
    (cell10 ==0) ? 2'b00 : 
    (cell20 ==0) ? 2'b00 : 
    (cell30 ==0) ? 2'b00 : 
    (cell01 ==0) ? 2'b01 : 
    (cell11 ==0) ? 2'b01 : 
    (cell21 ==0) ? 2'b01 : 
    (cell31 ==0) ? 2'b01 : 
    (cell02 ==0) ? 2'b10 : 
    (cell12 ==0) ? 2'b10 : 
    (cell22 ==0) ? 2'b10 : 
    (cell32 ==0) ? 2'b10 : 
    (cell03 ==0) ? 2'b11 : 
    (cell13 ==0) ? 2'b11 : 
    (cell23 ==0) ? 2'b11 : 
    (cell33 ==0) ? 2'b11 : 2'bxx;

assign valid = (zero_count == 1);

endmodule