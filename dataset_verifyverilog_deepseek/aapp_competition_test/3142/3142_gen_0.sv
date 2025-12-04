module digit_sum_finder(
  input clk,
  input rst_n,
  input start,
  input [15:0] A,
  input [15:0] B,
  input [5:0] S,
  output reg [13:0] count,
  output reg [15:0] smallest_num,
  output reg done
);

  reg [15:0] current_num;
  reg computing;

  wire [3:0] thousands = current_num / 1000;
  wire [3:0] hundreds = (current_num % 1000) / 100;
  wire [3:0] tens = (current_num % 100) / 10;
  wire [3:0] units = current_num % 10;
  wire [5:0] digit_sum = thousands + hundreds + tens + units;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count <= 14'b0;
      smallest_num <= 16'b0;
      done <= 1'b0;
      current_num <= 16'b0;
      computing <= 1'b0;
    end else begin
      if (start && !computing) begin
        current_num <= A;
        count <= 14'b0;
        smallest_num <= 16'hffff;
        done <= 1'b0;
        computing <= 1'b1;
      end
      
      if (computing) begin
        if (current_num <= B) begin
          if (digit_sum == S) begin
            count <= count + 1;
            if (current_num < smallest_num) begin
              smallest_num <= current_num;
            end
          end
          current_num <= current_num + 1;
        end else begin
          done <= 1'b1;
          computing <= 1'b0;
        end
      end
    end
  end
endmodule