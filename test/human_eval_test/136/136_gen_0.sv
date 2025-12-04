module min_max_finder(
  input  clk,
  input  rst_n,
  input  start,
  input  signed [7:0] data_in [7:0],
  output reg signed [7:0] a,
  output reg signed [7:0] b,
  output reg done
);

  reg [2:0] idx;
  reg       busy;

  // Sequential control and outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a    <= 8'sd128;  // sentinel None for largest negative
      b    <= 8'sd127;  // sentinel None for smallest positive
      done <= 1'b0;
      busy <= 1'b0;
      idx  <= 3'd0;
    end else begin
      if (start && !busy) begin
        // Initialize for new computation
        a    <= 8'sd128;
        b    <= 8'sd127;
        done <= 1'b0;
        busy <= 1'b1;
        idx  <= 3'd0;
      end else if (busy) begin
        // Process current element
        // Largest negative
        if ($signed(data_in[idx]) < 0 && $signed(data_in[idx]) > a)
          a <= data_in[idx];

        // Smallest positive
        if ($signed(data_in[idx]) > 0 && ($signed(data_in[idx]) < b))
          b <= data_in[idx];

        // Move to next index
        if (idx == 3'd7) begin
          busy <= 1'b0;
          done <= 1'b1;
        end
        idx <= idx + 3'd1;
      end
      // When not busy and no new start, hold a, b, done
    end
  end

endmodule