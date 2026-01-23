module check_element(input [7:0] element_to_match, input [3:0][7:0] array_data, output result);
assign result = (array_data[0] == element_to_match) && (array_data[1] == element_to_match) && (array_data[2] == element_to_match) && (array_data[3] == element_to_match);
endmodule