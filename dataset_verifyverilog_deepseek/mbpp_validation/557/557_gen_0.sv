module toggle_case(input reg [63:0] str_in, output reg [63:0] str_out);
  logic [7:0] temp_in [0:7];
  logic [7:0] temp_out [0:7];
  always_comb begin
    for (int i = 0; i < 8; i++) begin
      temp_in[i] = str_in[(7-i)*8 +: 8];
      if (temp_in[i] >= 8'd65 && temp_in[i] <= 8'd90)
        temp_out[i] = temp_in[i] + 8'd32;
      else if (temp_in[i] >= 8'd97 && temp_in[i] <= 8'd122)
        temp_out[i] = temp_in[i] - 8'd32;
      else
        temp_out[i] = temp_in[i];
    end
    str_out = {temp_out[0], temp_out[1], temp_out[2], temp_out[3],
               temp_out[4], temp_out[5], temp_out[6], temp_out[7]};
  end
endmodule