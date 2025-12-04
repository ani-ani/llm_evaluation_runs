module stone_pile(
  input  clk,
  input  rst_n,
  input  start,
  input  [4:0] n,
  output reg [4:0] levels [0:7],
  output reg done
);

  reg [4:0] base_n;
  reg [3:0] level_cnt;
  reg [3:0] done_cnt;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      base_n    <= 5'd0;
      level_cnt <= 4'd0;
      done_cnt  <= 4'd0;
      done      <= 1'b0;
      levels[0] <= 5'd0;
      levels[1] <= 5'd0;
      levels[2] <= 5'd0;
      levels[3] <= 5'd0;
      levels[4] <= 5'd0;
      levels[5] <= 5'd0;
      levels[6] <= 5'd0;
      levels[7] <= 5'd0;
    end else begin
      // Default: clear done when not asserted in this cycle
      done <= 1'b0;

      // Capture start: begin processing window
      if (start) begin
        base_n    <= n;
        level_cnt <= 4'd0;
        done_cnt  <= 4'd10; // done asserts 10 cycles after start
      end

      // Generate levels sequentially: levels[i] valid i cycles after start
      if (done_cnt != 4'd0) begin
        // Level generation: only first 8 cycles after start
        if (level_cnt < 4'd8) begin
          if (level_cnt == 4'd0) begin
            levels[0] <= base_n;
          end else begin
            levels[level_cnt] <= levels[level_cnt-1] + 5'd2;
          end
          level_cnt <= level_cnt + 4'd1;
        end

        // Done counter: assert when it reaches 1
        if (done_cnt == 4'd1) begin
          done <= 1'b1;
        end
        done_cnt <= done_cnt - 4'd1;
      end
    end
  end

endmodule