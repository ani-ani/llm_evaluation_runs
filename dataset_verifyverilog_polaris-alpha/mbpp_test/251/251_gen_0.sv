module insert_element(
  input  [63:0]        element_in,
  input  [3:0]         input_length,
  input  [7:0][63:0]   list_in,
  output [15:0][63:0]  list_out
);

  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : gen_insert
      // For i < input_length: insert element_in then list_in[i]
      // For i >= input_length: positions are left unassigned (undefined)
      assign list_out[2*i]   = (i < input_length) ? element_in : {64{1'bx}};
      assign list_out[2*i+1] = (i < input_length) ? list_in[i] : {64{1'bx}};
    end
  endgenerate

endmodule