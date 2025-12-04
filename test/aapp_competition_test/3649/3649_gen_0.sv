module bitstring_subsequence(
  input  [3:0] a,  // '00' subsequence count
  input  [3:0] b,  // '01' count
  input  [3:0] c,  // '10' count
  input  [3:0] d,  // '11' count
  output reg [7:0] string_out,  // left-aligned, MSB first, pad with 0
  output reg       impossible
);

  integer n0, n1;
  integer i;
  reg [7:0] temp_str;
  reg       valid_n0, valid_n1;

  // Combinational logic
  always @* begin
    // Default values
    n0 = -1;
    n1 = -1;
    valid_n0 = 0;
    valid_n1 = 0;
    temp_str = 8'b0;
    string_out = 8'b0;
    impossible = 1'b1;

    // Find n0 in range 0..6 such that n0*(n0-1)/2 == a
    for (i = 0; i <= 6; i = i + 1) begin
      if ((i * (i - 1) / 2) == a && !valid_n0) begin
        n0 = i;
        valid_n0 = 1'b1;
      end
    end

    // Find n1 in range 0..6 such that n1*(n1-1)/2 == d
    for (i = 0; i <= 6; i = i + 1) begin
      if ((i * (i - 1) / 2) == d && !valid_n1) begin
        n1 = i;
        valid_n1 = 1'b1;
      end
    end

    // Check validity and construct string if possible
    if (!valid_n0 || !valid_n1) begin
      impossible = 1'b1;
      string_out = 8'b0;
    end else if ((n0 + n1) > 8) begin
      impossible = 1'b1;
      string_out = 8'b0;
    end else if ((b + c) != (n0 * n1)) begin
      impossible = 1'b1;
      string_out = 8'b0;
    end else begin
      // Now (b + c) == n0*n1, decide arrangement
      if ((b == (n0 * n1)) && (c == 0)) begin
        // pattern: all 0s then all 1s
        temp_str = 8'b0;
        for (i = 0; i < n0; i = i + 1) begin
          temp_str[7 - i] = 1'b0;
        end
        for (i = 0; i < n1; i = i + 1) begin
          temp_str[7 - (n0 + i)] = 1'b1;
        end
        // remaining bits already 0
        string_out = temp_str;
        impossible = 1'b0;
      end else if ((c == (n0 * n1)) && (b == 0)) begin
        // pattern: all 1s then all 0s
        temp_str = 8'b0;
        for (i = 0; i < n1; i = i + 1) begin
          temp_str[7 - i] = 1'b1;
        end
        for (i = 0; i < n0; i = i + 1) begin
          temp_str[7 - (n1 + i)] = 1'b0;
        end
        // remaining bits already 0
        string_out = temp_str;
        impossible = 1'b0;
      end else begin
        impossible = 1'b1;
        string_out = 8'b0;
      end
    end
  end

endmodule