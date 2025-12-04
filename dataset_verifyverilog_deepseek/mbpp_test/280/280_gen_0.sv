module sequential_search (
  input clk,
  input rst_n,
  input start,
  input [7:0] item,
  input [7:0] [7:0] array,
  output reg found,
  output reg [3:0] index,
  output reg done
);

  reg [3:0] counter;
  reg start_reg;

  wire start_rise = start && !start_reg;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      found <= 0;
      index <= 4'b1111;
      done <= 0;
      counter <= 0;
      start_reg <= 0;
    end else begin
      start_reg <= start;
      if (start_rise) begin
        counter <= 0;
        done <= 0;
        found <= 0;
        index <= 4'b1111;
      end else if (!done) begin
        if (counter < 8) begin
          if (array[counter] == item) begin
            found <= 1'b1;
            index <= counter;
            done <= 1'b1;
          end else begin
            counter <= counter + 4'b1;
          end
        end else begin
          found <= 1'b0;
          index <= 4'b1111;
          done <= 1'b1;
        end
      end
    end
  end

endmodule