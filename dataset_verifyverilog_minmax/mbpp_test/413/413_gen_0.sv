
module tuple_element_extractor (
  input [1:0] n,
  input [3:0][2:0][15:0] tuples,
  output logic [3:0][15:0] result
);

  always @* begin
    result = tuples[n]; // Select element n from each of the 4 tuples
  end

endmodule
