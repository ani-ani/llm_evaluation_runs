module char_remover (
  input [63:0] str_in,
  input [7:0] ch,
  output [63:0] str_out
);

  logic [7:0] bytes_in [0:7];
  logic [7:0] bytes_out [0:7];

  assign bytes_in[0] = str_in[63:56];
  assign bytes_in[1] = str_in[55:48];
  assign bytes_in[2] = str_in[47:40];
  assign bytes_in[3] = str_in[39:32];
  assign bytes_in[4] = str_in[31:24];
  assign bytes_in[5] = str_in[23:16];
  assign bytes_in[6] = str_in[15:8];
  assign bytes_in[7] = str_in[7:0];

  logic [3:0] first_idx;
  logic [3:0] last_idx;
  logic [7:0] matches;

  always_comb begin
    for (int i=0; i<8; i=i+1)
      matches[i] = (bytes_in[i] == ch);

    first_idx = 8;
    for (int i=0; i<8; i=i+1)
      if (first_idx == 8 && matches[i]) first_idx = i;

    last_idx = 8;
    for (int i=7; i>=0; i=i-1)
      if (last_idx == 8 && matches[i]) last_idx = i;
  end

  logic [7:0] remove;
  generate
    for (genvar i=0; i<8; i=i+1) begin
      assign remove[i] = ( (i == first_idx && first_idx != 8) ||
                          (i == last_idx && last_idx != 8 && first_idx != last_idx) ) ? 1'b1 : 1'b0;
    end
  endgenerate

  logic [7:0] keep;
  assign keep = ~remove;

  logic [3:0] prefix_sum [0:7];
  assign prefix_sum[0] = 0;
  generate
    for (genvar i=1; i<8; i=i+1) begin
      assign prefix_sum[i] = prefix_sum[i-1] + keep[i-1];
    end
  endgenerate

  generate
    for (genvar j=0; j<8; j=j+1) begin
      assign bytes_out[j] = 
        ((keep[0] && (prefix_sum[0] == j)) ? bytes_in[0] : 8'd0) |
        ((keep[1] && (prefix_sum[1] == j)) ? bytes_in[1] : 8'd0) |
        ((keep[2] && (prefix_sum[2] == j)) ? bytes_in[2] : 8'd0) |
        ((keep[3] && (prefix_sum[3] == j)) ? bytes_in[3] : 8'd0) |
        ((keep[4] && (prefix_sum[4] == j)) ? bytes_in[4] : 8'd0) |
        ((keep[5] && (prefix_sum[5] == j)) ? bytes_in[5] : 8'd0) |
        ((keep[6] && (prefix_sum[6] == j)) ? bytes_in[6] : 8'd0) |
        ((keep[7] && (prefix_sum[7] == j)) ? bytes_in[7] : 8'd0);
    end
  endgenerate

  assign str_out = {bytes_out[0], bytes_out[1], bytes_out[2], bytes_out[3],
                   bytes_out[4], bytes_out[5], bytes_out[6], bytes_out[7]};

endmodule