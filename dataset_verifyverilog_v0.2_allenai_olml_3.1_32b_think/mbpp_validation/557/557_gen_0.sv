module toggle_case (input reg [7:0] char_0, input reg [7:0] char_1, input reg [7:0] char_2, input reg [7:0] char_3, input reg [7:0] char_4, input reg [7:0] char_5, input reg [7:0] char_6, input reg [7:0] char_7, output reg [7:0] out_0, output reg [7:0] out_1, output reg [7:0] out_2, output reg [7:0] out_3, output reg [7:0] out_4, output reg [7:0] out_5, output reg [7:0] out_6, output reg [7:0] out_7);
assign out_0 = (char_0 >= 8'h41 && char_0 <= 8'h5A) ? (char_0 + 8'h20) : (char_0 >= 8'h61 && char_0 <= 8'h7A) ? (char_0 - 8'h20) : char_0;
assign out_1 = (char_1 >= 8'h41 && char_1 <= 8'h5A) ? (char_1 + 8'h20) : (char_1 >= 8'h61 && char_1 <= 8'h7A) ? (char_1 - 8'h20) : char_1;
assign out_2 = (char_2 >= 8'h41 && char_2 <= 8'h5A) ? (char_2 + 8'h20) : (char_2 >= 8'h61 && char_2 <= 8'h7A) ? (char_2 - 8'h20) : char_2;
assign out_3 = (char_3 >= 8'h41 && char_3 <= 8'h5A) ? (char_3 + 8'h20) : (char_3 >= 8'h61 && char_3 <= 8'h7A) ? (char_3 - 8'h20) : char_3;
assign out_4 = (char_4 >= 8'h41 && char_4 <= 8'h5A) ? (char_4 + 8'h20) : (char_4 >= 8'h61 && char_4 <= 8'h7A) ? (char_4 - 8'h20) : char_4;
assign out_5 = (char_5 >= 8'h41 && char_5 <= 8'h5A) ? (char_5 + 8'h20) : (char_5 >= 8'h61 && char_5 <= 8'h7A) ? (char_5 - 8'h20) : char_5;
assign out_6 = (char_6 >= 8'h41 && char_6 <= 8'h5A) ? (char_6 + 8'h20) : (char_6 >= 8'h61 && char_6 <= 8'h7A) ? (char_6 - 8'h20) : char_6;
assign out_7 = (char_7 >= 8'h41 && char_7 <= 8'h5A) ? (char_7 + 8'h20) : (char_7 >= 8'h61 && char_7 <= 8'h7A) ? (char_7 - 8'h20) : char_7;
endmodule