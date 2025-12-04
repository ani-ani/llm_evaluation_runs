// char_replacer: combinational replacement of spaces, commas, and dots with colons
module char_replacer (
  input  [3:0]          str_len,
  input  [15:0][7:0]    in_str,
  output [15:0][7:0]    out_str
);

  // Process all 16 characters combinatorially in parallel
  always @(*) begin
    for (int i = 0; i < 16; i = i + 1) begin
      if (i < str_len) begin
        if (in_str[i] == 8'h20 || in_str[i] == 8'h2C || in_str[i] == 8'h2E)
          out_str[i] = 8'h3A; // ':'
        else
          out_str[i] = in_str[i];
      end else begin
        out_str[i] = 8'h00;
      end
    end
  end

endmodule