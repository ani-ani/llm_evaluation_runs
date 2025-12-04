module array_swap_first_last (
  input [3:0] size,
  input [63:0] array_in,
  output logic [63:0] array_out
);

  always_comb begin
    case(size)
      4'd1: array_out = array_in;
      4'd2: array_out = {array_in[63:16], array_in[7:0], array_in[15:8]};
      4'd3: array_out = {array_in[63:24], array_in[7:0], array_in[15:8], array_in[23:16]};
      4'd4: array_out = {array_in[63:32], array_in[7:0], array_in[15:8], array_in[23:16], array_in[31:24]};
      4'd5: array_out = {array_in[63:40], array_in[7:0], array_in[31:24], array_in[23:16], array_in[15:8], array_in[39:32]};
      4'd6: array_out = {array_in[63:48], array_in[7:0], array_in[39:32], array_in[31:24], array_in[23:16], array_in[15:8], array_in[47:40]};
      4'd7: array_out = {array_in[63:56], array_in[7:0], array_in[47:40], array_in[39:32], array_in[31:24], array_in[23:16], array_in[15:8], array_in[55:48]};
      4'd8: array_out = {array_in[7:0], array_in[55:48], array_in[47:40], array_in[39:32], array_in[31:24], array_in[23:16], array_in[15:8], array_in[63:56]};
      default: array_out = 'x;
    endcase
  end

endmodule