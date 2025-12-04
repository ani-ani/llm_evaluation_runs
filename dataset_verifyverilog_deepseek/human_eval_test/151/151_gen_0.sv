module sum_odd_squares (
  input clk,
  input rst_n,
  input start,
  input [7:0][15:0] numbers,
  output reg [19:0] sum,
  output reg done
);

  reg running;
  reg [2:0] counter;

  wire [7:0] integer_part = numbers[counter][15:8];
  wire [7:0] fractional_bits = numbers[counter][7:0];
  wire is_valid = (fractional_bits == 8'd0) && (integer_part > 8'd0) && integer_part[0];

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum <= 20'd0;
      done <= 1'b0;
      counter <= 3'd0;
      running <= 1'b0;
    end else begin
      if (start && !running) begin
        running <= 1'b1;
        sum <= 20'd0;
        counter <= 3'd0;
        done <= 1'b0;
      end else if (running) begin
        if (counter < 3'd8) begin
          if (is_valid) begin
            sum <= sum + (integer_part * integer_part);
          end
          if (counter == 3'd7) begin
            running <= 1'b0;
            done <= 1'b1;
          end
          counter <= counter + 3'd1;
        end
      end
    end
  end
endmodule