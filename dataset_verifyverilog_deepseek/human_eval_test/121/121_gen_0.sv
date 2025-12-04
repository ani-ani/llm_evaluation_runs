module odd_even_sum(
  input clk,
  input rst_n,
  input start,
  input [15:0] data,
  input [3:0] index,
  input [3:0] count,
  output reg [15:0] sum_result,
  output reg done
);

  reg [3:0] count_reg;
  reg [3:0] counter;
  reg [1:0] delay_counter;
  reg processing_active;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum_result <= 16'h0;
      done <= 1'b0;
      count_reg <= 4'h0;
      counter <= 4'h0;
      delay_counter <= 2'h0;
      processing_active <= 1'b0;
    end else begin
      if (start) begin
        count_reg <= count;
        sum_result <= 16'h0;
        counter <= 4'h0;
        processing_active <= 1'b1;
        done <= 1'b0;
        delay_counter <= 2'h0;
      end else if (processing_active) begin
        if (counter < count_reg) begin
          if (index[0] == 1'b0 && data[0] == 1'b1) begin
            sum_result <= sum_result + data;
          end
          counter <= counter + 1;
        end else begin
          if (delay_counter == 2'h0) begin
            delay_counter <= 2'h1;
          end else begin
            delay_counter <= delay_counter - 2'h1;
          end
          if (delay_counter == 2'h1) begin
            done <= 1'b1;
            processing_active <= 1'b0;
          end
        end
      end
    end
  end

endmodule