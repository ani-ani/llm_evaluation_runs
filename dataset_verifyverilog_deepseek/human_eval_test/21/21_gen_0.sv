module rescale_unit (
  input clk,
  input rst_n,
  input start,
  input [31:0] numbers [0:7],
  output reg [31:0] result [0:7],
  output reg done
);

  reg [31:0] captured_numbers [0:7];
  reg [31:0] min_val, max_val, range_val;
  reg [4:0] counter;
  reg computing;
  reg [47:0] remainders [0:7];
  reg [31:0] quotients [0:7];
  wire range_is_zero = (range_val == 0);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      computing <= 0;
      counter <= 0;
      for (int i=0; i<8; i=i+1) begin
        captured_numbers[i] <= 0;
        remainders[i] <= 0;
        quotients[i] <= 0;
      end
      min_val <= 0;
      max_val <= 0;
      range_val <= 0;
    end else begin
      if (start) begin
        captured_numbers <= numbers;
        computing <= 1;
        counter <= 0;
        done <= 0;
        min_val <= numbers[0];
        max_val <= numbers[0];
        for (int i=1; i<8; i=i+1) begin
          if (numbers[i] < min_val) min_val <= numbers[i];
          if (numbers[i] > max_val) max_val <= numbers[i];
        end
        range_val <= max_val - min_val;
        for (int i=0; i<8; i=i+1) begin
          remainders[i] <= { (numbers[i] - min_val), 16'b0 };
          quotients[i] <= 0;
        end
      end else if (computing) begin
        if (counter == 14) begin
          computing <= 0;
          done <= 1;
          counter <= 0;
          if (range_is_zero) for (int i=0; i<8; i=i+1) result[i] <= 0;
          else for (int i=0; i<8; i=i+1) result[i] <= quotients[i];
        end else begin
          counter <= counter + 1;
        end
        if (!range_is_zero) begin
          for (int i=0; i<8; i=i+1) begin
            automatic logic [47:0] rem_shifted = remainders[i] << 1;
            automatic logic [31:0] rem_upper = rem_shifted[47:16];
            automatic logic cmp = (rem_upper >= range_val);
            if (cmp) begin
              remainders[i] <= { (rem_upper - range_val), rem_shifted[15:0] };
              quotients[i] <= (quotients[i] << 1) | 1'b1;
            end else begin
              remainders[i] <= rem_shifted;
              quotients[i] <= (quotients[i] << 1);
            end
          end
        end
      end else begin
        done <= 0;
      end
    end
  end

endmodule