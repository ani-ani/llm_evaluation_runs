module digit_counter(
  input        clk,
  input        rst_n,
  input        start,
  input  [127:0] str,
  output reg [4:0] count,
  output reg       done
);

  reg [3:0]  index;
  reg        active;
  reg        start_d;

  // Edge detect for start
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      start_d <= 1'b0;
    else
      start_d <= start;
  end

  wire start_rise = start & ~start_d;

  // Main sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count  <= 5'd0;
      done   <= 1'b0;
      index  <= 4'd0;
      active <= 1'b0;
    end else begin
      // Default: keep current values

      // Start a new counting sequence on rising edge of start
      if (start_rise) begin
        count  <= 5'd0;
        done   <= 1'b0;
        index  <= 4'd0;
        active <= 1'b1;
      end else if (active) begin
        // Process current character
        // MSB-first: character at position (15 - index)
        // Byte select: [8*(15-i)+7 : 8*(15-i)] = [127-8*i : 120-8*i]
        if ((str[127 - 8*index -: 8] >= 8'h30) && (str[127 - 8*index -: 8] <= 8'h39)) begin
          count <= count + 5'd1;
        end

        if (index == 4'd15) begin
          done   <= 1'b1;
          active <= 1'b0;
        end

        index <= index + 4'd1;
      end
    end
  end

endmodule