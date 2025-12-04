module bitstring_subsequence (
    input [3:0] a,
    input [3:0] b,
    input [3:0] c,
    input [3:0] d,
    output reg [7:0] string_out,
    output reg impossible
);

  always @(*) begin
    integer n0, n1, i;
    reg found = 0;
    string_out = 0;
    impossible = 1;
    for (n0=0; n0<=6 && !found; n0++) begin
      if (a != (n0*(n0-1))/2) continue;
      for (n1=0; n1<=6 && !found; n1++) begin
        if (d != (n1*(n1-1))/2) continue;
        if (n0 + n1 > 8) continue;
        if ( (b + c) != (n0 * n1) ) continue;
        if (c == 0) begin
          // zeros-then-ones
          for (i=0; i<n0; i++) begin
            string_out[7-i] = 1'b0;
          end
          for (i=0; i<n1; i++) begin
            string_out[7-n0-i] = 1'b1;
          end
          impossible = 0;
          found = 1;
        end
        else if (b == 0) begin
          // ones-then-zeros
          for (i=0; i<n1; i++) begin
            string_out[7-i] = 1'b1;
          end
          for (i=0; i<n0; i++) begin
            string_out[7-n1-i] = 1'b0;
          end
          impossible = 0;
          found = 1;
        end
      end
    end
  end

endmodule