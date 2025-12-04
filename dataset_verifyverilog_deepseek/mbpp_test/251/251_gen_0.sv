module insert_element (
  input [63:0] element_in,
  input [3:0] input_length,
  input [7:0][63:0] list_in,
  output logic [15:0][63:0] list_out
);

  always_comb begin
    list_out = '{default: '0};
    for (int j = 0; j < 8; j++) begin
      if (j < input_length) begin
        list_out[2*j]   = element_in;
        list_out[2*j+1] = list_in[j];
      end
    end
  end

endmodule