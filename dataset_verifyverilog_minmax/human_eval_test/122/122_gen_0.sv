module sum_two_digit_elements(
  input clk,
  input rst_n,
  input start,
  input signed [12:0] arr [0:15],
  input [3:0] k,
  output reg signed [10:0] sum,
  output reg done
);

  reg [3:0] idx;
  reg active;
  reg signed [12:0] acc;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      acc <= 0;
      idx <= 0;
      active <= 0;
      done <= 0;
      sum <= 0;
    end
    else begin
      if (start && !active) begin
        acc <= 0;
        idx <= 0;
        active <= 1;
        done <= 0;
      end
      else if (active) begin
        // Compute absolute value of current element
        reg [12:0] abs_val;
        abs_val = (arr[idx][12]) ? ~arr[idx] + 1 : arr[idx];

        // Check if absolute value is between 10 and 99
        if (abs_val >= 10 && abs_val <= 99) begin
          acc <= acc + arr[idx];
        end

        idx <= idx + 1;

        if (idx == k-1) begin
          active <= 0;
          done <= 1;
          
          // Output conversion with saturation
          if (acc[12] == 0) begin
            if (acc <= 1023)
              sum <= acc;
            else
              sum <= 1023;
          end
          else begin
            if (acc >= -1024)
              sum <= acc;
            else
              sum <= -1024;
          end
        end
      end
    end
  end
endmodule