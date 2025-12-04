module grey_cell_counter (
  input clk,
  input rst_n,
  input start,
  input [7:0] R,
  input [7:0] C,
  input [15:0] K,
  output reg [15:0] count,
  output reg done
);

  reg [15:0] step;
  reg [7:0] i, j;
  reg direction; // 1=right, 0=left

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count <= 16\'b0;
      done <= 1\'b0;
      step <= 16\'b0;
      i <= 8\'b0;
      j <= 8\'b0;
      direction <= 1\'b1;
    end else if (start) begin
      count <= 16\'b0;
      done <= 1\'b0;
      step <= 16\'b0;
      i <= 8\'b0;
      j <= 8\'b0;
      direction <= 1\'b1;
    end else if (!done) begin
      if (step == K) begin
        done <= 1\'b1;
      end else begin
        if ((i & j) == 0) count <= count + 1;

        step <= step + 1;
        
        if (direction) begin
          if (j < (C - 1)) j <= j + 1;
          else begin
            i <= i + 1;
            direction <= 0;
          end
        end else begin
          if (j > 0) j <= j - 1;
          else begin
            i <= i + 1;
            direction <= 1;
          end
        end
      end
    end
  end

endmodule