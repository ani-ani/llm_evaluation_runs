module flip_case (
  input reg [127:0] string_in,
  output reg [127:0] string_out
);

  always_comb begin
    for (int i = 0; i < 16; i = i + 1) begin
      automatic logic [7:0] current_byte = string_in[i*8 +: 8];
      if ((current_byte >= 8'h61) && (current_byte <= 8'h7A)) begin
        string_out[i*8 +: 8] = current_byte ^ 8'h20;
      end else if ((current_byte >= 8'h41) && (current_byte <= 8'h5A)) begin
        string_out[i*8 +: 8] = current_byte ^ 8'h20;
      end else begin
        string_out[i*8 +: 8] = current_byte;
      end
    end
  end

endmodule