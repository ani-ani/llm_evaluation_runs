module elementwise_sub(
  input [3:0][7:0] a,
  input [3:0][7:0] b,
  input [1:0] valid_entries,
  output logic [3:0][7:0] diff
);

  always_comb begin
    integer N;
    case (valid_entries)
      2'b00: N = 4;
      2'b01: N = 1;
      2'b10: N = 2;
      2'b11: N = 3;
      default: N = 4;
    endcase

    for (int i = 0; i < 4; i++) begin
      if (i < N) begin
        diff[i] = $signed(a[i]) - $signed(b[i]);
      end else begin
        diff[i] = 8'b0;
      end
    end
  end

endmodule