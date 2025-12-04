module str_to_tuple (input [127:0] data_in, input [3:0] length, output reg [127:0] tuple_data, output reg [4:0] tuple_length);
  wire [15:0] valid;
  wire [4:0] count [16:0];
  wire [127:0] tuple_data_wire;

  generate
    for (genvar i=0; i<16; i++) begin : valid_gen
      assign valid[i] = (i < length) && (data_in[8*i +:8] != 8'h20);
    end
  endgenerate

  assign count[0] = 5'd0;

  generate
    for (genvar i=1; i<=16; i++) begin : count_gen
      assign count[i] = count[i-1] + valid[i-1];
    end
  endgenerate

  generate
    for (genvar k=0; k<16; k++) begin : output_byte
      wire [7:0] byte_out;
      assign byte_out = 8'h00;

      for (genvar j=0; j<16; j++) begin : input_sel
        wire cond = (valid[j] && (count[j] == 5'(k)));
        assign byte_out = cond ? data_in[8*j +:8] : byte_out;
      end
      assign tuple_data_wire[8*k +:8] = byte_out;
    end
  endgenerate

  always_comb begin
    tuple_data = tuple_data_wire;
    tuple_length = count[16];
  end
endmodule