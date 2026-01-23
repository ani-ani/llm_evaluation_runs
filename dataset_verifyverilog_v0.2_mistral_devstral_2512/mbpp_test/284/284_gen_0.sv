module check_element (
  input [7:0] element_to_match,
  input [3:0][7:0] array_data,
  output result
);

  wire [3:0] match_results;
  assign match_results[0] = (array_data[0] == element_to_match);
  assign match_results[1] = (array_data[1] == element_to_match);
  assign match_results[2] = (array_data[2] == element_to_match);
  assign match_results[3] = (array_data[3] == element_to_match);

  assign result = &match_results;

endmodule