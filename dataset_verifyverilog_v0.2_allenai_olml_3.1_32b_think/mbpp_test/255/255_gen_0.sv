module combinations_with_replacement (
    input [2:0] num_elements,
    input [2:0] combo_length,
    input [3:0][7:0] elements,
    output reg [15:0] num_combos,
    output reg [9:0][3:0][7:0] combos
);

localparam [3:0][3:0] total_table = {
    {4{4'd1}}, {4'd2,4'd3,4'd4,4'd5}, {4'd3,4'd6,4'd10,4'd15}, {4'd4,4'd10,4'd20,4'd35}
};

integer n_val = num_elements;
integer m_val = combo_length;
integer n_idx = n_val -1;
integer m_idx = m_val -1;
integer total;
if (n_val ==1) total =1;
else total = total_table[n_idx][m_idx];
assign num_combos = (total > 10) ? 10 : total;

// Assign all combos to zero
assign combos[0][0][7:0] = 8'b0;
assign combos[0][1][7:0] = 8'b0;
assign combos[0][2][7:0] = 8'b0;
assign combos[0][3][7:0] = 8'b0;
assign combos[1][0][7:0] = 8'b0;
assign combos[1][1][7:0] = 8'b0;
assign combos[1][2][7:0] = 8'b0;
assign combos[1][3][7:0] = 8'b0;
assign combos[2][0][7:0] = 8'b0;
assign combos[2][1][7:0] = 8'b0;
assign combos[2][2][7:0] = 8'b0;
assign combos[2][3][7:0] = 8'b0;
assign combos[3][0][7:0] = 8'b0;
assign combos[3][1][7:0] = 8'b0;
assign combos[3][2][7:0] = 8'b0;
assign combos[3][3][7:0] = 8'b0;
assign combos[4][0][7:0] = 8'b0;
assign combos[4][1][7:0] = 8'b0;
assign combos[4][2][7:0] = 8'b0;
assign combos[4][3][7:0] = 8'b0;
assign combos[5][0][7:0] = 8'b0;
assign combos[5][1][7:0] = 8'b0;
assign combos[5][2][7:0] = 8'b0;
assign combos[5][3][7:0] = 8'b0;
assign combos[6][0][7:0] = 8'b0;
assign combos[6][1][7:0] = 8'b0;
assign combos[6][2][7:0] = 8'b0;
assign combos[6][3][7:0] = 8'b0;
assign combos[7][0][7:0] = 8'b0;
assign combos[7][1][7:0] = 8'b0;
assign combos[7][2][7:0] = 8'b0;
assign combos[7][3][7:0] = 8'b0;
assign combos[8][0][7:0] = 8'b0;
assign combos[8][1][7:0] = 8'b0;
assign combos[8][2][7:0] = 8'b0;
assign combos[8][3][7:0] = 8'b0;
assign combos[9][0][7:0] = 8'b0;
assign combos[9][1][7:0] = 8'b0;
assign combos[9][2][7:0] = 8'b0;
assign combos[9][3][7:0] = 8'b0;

endmodule