module dict_sum (
    input [7:0] num_items,
    input [7:0][15:0] values,
    output [15:0] sum
);
assign enable_0 = num_items > 0;
assign enable_1 = num_items > 1;
assign enable_2 = num_items > 2;
assign enable_3 = num_items > 3;
assign enable_4 = num_items > 4;
assign enable_5 = num_items > 5;
assign enable_6 = num_items > 6;
assign enable_7 = num_items > 7;
wire [15:0] term0 = values[0] & ({16{enable_0}});
wire [15:0] term1 = values[1] & ({16{enable_1}});
wire [15:0] term2 = values[2] & ({16{enable_2}});
wire [15:0] term3 = values[3] & ({16{enable_3}});
wire [15:0] term4 = values[4] & ({16{enable_4}});
wire [15:0] term5 = values[5] & ({16{enable_5}});
wire [15:0] term6 = values[6] & ({16{enable_6}});
wire [15:0] term7 = values[7] & ({16{enable_7}});
assign sum = term0 + term1 + term2 + term3 + term4 + term5 + term6 + term7;
endmodule