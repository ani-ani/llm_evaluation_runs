module meow_factor (
    input clk,
    input rst_n,
    input [7:0] char_0, char_1, char_2, char_3, char_4, char_5, char_6, char_7,
    output reg [7:0] meow_factor,
    output reg valid
);
localparam MEOW = { 
    8'h6d, 8'h65, 8'h6f, 8'h77 
};
wire [1:0] found = 2'b00;
wire [1:0] match0 = (char_0 == MEOW[0] && char_1 == MEOW[1] && char_2 == MEOW[2] && char_3 == MEOW[3]) ? 2'b01 : 2'b00;
found = match0 ? 2'b01 : found;
wire [1:0] match1 = (char_1 == MEOW[0] && char_2 == MEOW[1] && char_3 == MEOW[2] && char_4 == MEOW[3]) ? 2'b01 : 2'b00;
found = match1 ? 2'b01 : found;
wire [1:0] match2 = (char_2 == MEOW[0] && char_3 == MEOW[1] && char_4 == MEOW[2] && char_5 == MEOW[3]) ? 2'b01 : 2'b00;
found = match2 ? 2'b01 : found;
wire [1:0] match3 = (char_3 == MEOW[0] && char_4 == MEOW[1] && char_5 == MEOW[2] && char_6 == MEOW[3]) ? 2'b01 : 2'b00;
found = match3 ? 2'b01 : found;
wire [1:0] match4 = (char_4 == MEOW[0] && char_5 == MEOW[1] && char_6 == MEOW[2] && char_7 == MEOW[3]) ? 2'b01 : 2'b00;
found = match4 ? 2'b01 : found;
assign meow_factor = found ? 8'h00 : 8'h04;
assign valid = rst_n ? 1'b0 : 1'b1;
endmodule