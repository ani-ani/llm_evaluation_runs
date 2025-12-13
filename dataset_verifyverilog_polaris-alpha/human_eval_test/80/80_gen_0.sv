module happy_string(
  input  [3:0]  str_len,
  input  [63:0] str_data,
  output reg    happy
);

  integer i;
  reg fail;
  reg [7:0] c0, c1, c2;

  always @* begin
    // Default
    happy = 1'b0;
    fail  = 1'b0;

    // Length check
    if (str_len < 3) begin
      happy = 1'b0;
    end else begin
      // Check all triplets in parallel (combinational loop)
      fail = 1'b0;
      for (i = 0; i <= 7 - 2; i = i + 1) begin
        if (i <= str_len - 3) begin
          c0 = str_data[i*8 +: 8];
          c1 = str_data[(i+1)*8 +: 8];
          c2 = str_data[(i+2)*8 +: 8];

          if ((c0 == c1) || (c0 == c2) || (c1 == c2)) begin
            fail = 1'b1;
          end
        end
      end

      happy = ~fail;
    end
  end

endmodule