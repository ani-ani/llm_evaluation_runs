module bisect_left (
  input clk,
  input rst_n,
  input start,
  input [3:0] value,
  input [7:0][3:0] array,
  output reg [3:0] index,
  output reg done
);

  reg [3:0] value_reg;
  reg [7:0][3:0] array_reg;
  reg [3:0] low_reg, high_reg;
  reg [2:0] count;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count <= 0;
      done <= 0;
      index <= 0;
      low_reg <= 0;
      high_reg <= 7;
      value_reg <= 0;
      array_reg <= {8{4'd0}};
    end else begin
      if (count == 0) begin
        done <= 0;
        if (start) begin
          value_reg <= value;
          array_reg <= array;
          low_reg <= 0;
          high_reg <= 7;
          count <= 1;
        end
      end else if (count < 4) begin
        automatic logic [3:0] mid = (low_reg + high_reg) >> 1;
        if (array_reg[mid] < value_reg) begin
          low_reg <= mid + 1;
        end else begin
          high_reg <= mid - 1;
        end
        count <= count + 1;
      end else if (count == 4) begin
        index <= low_reg;
        count <= 5;
      end else if (count == 5) begin
        done <= 1;
        count <= 0;
      end
    end
  end
endmodule