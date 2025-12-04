module insert_element (
  input [63:0] element_in,
  input [3:0] input_length,
  input [7:0][63:0] list_in,
  output wire [15:0][63:0] list_out
);
  genvar i;
  generate
    for (i = 0; i < 16; i = i + 1) begin : gen_out
      assign list_out[i] = 64'bx; // default undefined
    end
    for (i = 0; i < input_length; i = i + 1) begin : gen_ins
      assign list_out[2*i]     = element_in;
      assign list_out[2*i + 1] = list_in[i];
    end
  endgenerate
endmodule