module remove_kth_element (input [4:0] k, input [79:0] array_in, output [79:0] array_out);
  logic [4:0] packed_input[0:15];
  logic [4:0] packed_output[0:15];
  always_comb begin
    for (int i=0; i<16; i++) packed_input[i] = array_in[79-5*i -:5];
    if (k < 1 || k > 16) begin
      for (int i=0; i<16; i++) packed_output[i] = packed_input[i];
    end else begin
      for (int i=0; i<16; i++) begin
        if (i < (k-1)) packed_output[i] = packed_input[i];
        else if (i < 15) packed_output[i] = packed_input[i+1];
        else packed_output[i] = packed_input[15];
      end
    end
    for (int i=0; i<16; i++) array_out[79-5*i -:5] = packed_output[i];
  end
endmodule