module stone_pile (
  input clk,
  input rst_n,
  input start,
  input [4:0] n,
  output reg [4:0] levels[0:7],
  output reg done
);

  reg [3:0] cnt_done;
  reg [2:0] idx;
  reg processing;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      foreach (levels[i]) levels[i] <= 5'b0;
      cnt_done <= 4'b0;
      idx <= 3'b0;
      processing <= 1'b0;
    end else begin
      done <= 1'b0;

      if (start && !processing) begin
        processing <= 1'b1;
        idx <= 3'b0;
        cnt_done <= 4'b0;
        levels[0] <= n;
      end

      if (processing) begin
        cnt_done <= cnt_done + 1;

        if (cnt_done == 4'd9) begin
          done <= 1'b1;
          processing <= 1'b0;
        end else if ((cnt_done < 4'd8) && (idx < 3'd7)) begin
          idx <= idx + 1;
          levels[idx+1] <= levels[idx] + 5'd2;
        end
      end
    end
  end
endmodule