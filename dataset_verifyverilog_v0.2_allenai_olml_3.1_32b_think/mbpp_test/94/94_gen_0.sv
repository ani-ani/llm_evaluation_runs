module find_min_tuple (
    input [7:0] values [0:7],
    input [31:0] names [0:7],
    output [31:0] result_name
);
assign s1_0 = (values[0] < values[1]) ? 3'b000 : (values[0] > values[1] ? 3'b001 : 3'b000);
assign s1_1 = (values[2] < values[3]) ? 3'b010 : (values[2] > values[3] ? 3'b011 : 3'b010);
assign s1_2 = (values[4] < values[5]) ? 3'b100 : (values[4] > values[5] ? 3'b101 : 3'b100);
assign s1_3 = (values[6] < values[7]) ? 3'b110 : (values[6] > values[7] ? 3'b111 : 3'b110);
assign s2_0 = (values[s1_0] < values[s1_1]) ? s1_0 : (values[s1_0] > values[s1_1] ? s1_1 : (s1_0 < s1_1 ? s1_0 : s1_1));
assign s2_1 = (values[s1_2] < values[s1_3]) ? s1_2 : (values[s1_2] > values[s1_3] ? s1_3 : (s1_2 < s1_3 ? s1_2 : s1_3));
assign final_index = (values[s2_0] < values[s2_1]) ? s2_0 : (values[s2_0] > values[s2_1] ? s2_1 : (s2_0 < s2_1 ? s2_0 : s2_1));
assign result_name = names[final_index];
endmodule