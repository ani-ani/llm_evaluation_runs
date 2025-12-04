module rotation_index_finder (
  input clk,
  input rst_n,
  input start,
  input reg [3:0] arr [0:7],
  input reg [2:0] ranges [0:3][0:1],
  input reg [1:0] rotations,
  input reg [2:0] index,
  output reg [3:0] result,
  output reg done
);

  reg [2:0] cur_index;
  reg [1:0] cycles;
  reg [2:0] i;
  reg [2:0] left;
  reg [2:0] right;
  reg [2:0] next_index;

  always @(*) begin
    i = (rotations - 1) - cycles;
    left  = ranges[i][0];
    right = ranges[i][1];
    if (cur_index inside {[left : right]}) begin
      if (cur_index == left) next_index = right;
      else                   next_index = cur_index - 1;
    end else begin
      next_index = cur_index;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cur_index <= 3'b0;
      cycles    <= 2'b0;
      result    <= 4'b0;
      done      <= 1'b0;
    end else if (start) begin
      if (cycles == 2'b0) begin
        cur_index <= index;
        cycles    <= cycles + 1;
        result    <= 4'b0;
        done      <= 1'b0;
      end else if (cycles < rotations) begin
        cur_index <= next_index;
        cycles    <= cycles + 1;
        result    <= 4'b0;
        done      <= 1'b0;
      end else begin
        cur_index <= cur_index;
        cycles    <= cycles;
        result    <= arr[cur_index];
        done      <= 1'b1;
      end
    end else begin
      cur_index <= 3'b0;
      cycles    <= 2'b0;
      result    <= 4'b0;
      done      <= 1'b0;
    end
  end

endmodule