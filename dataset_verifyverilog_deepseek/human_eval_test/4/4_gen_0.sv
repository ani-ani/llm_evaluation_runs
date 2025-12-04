module mean_abs_dev(
  input clk,
  input rst_n,
  input start,
  input [31:0] num0, num1, num2, num3,
  output reg [31:0] mad,
  output reg done
);

  reg [31:0] num0_r, num1_r, num2_r, num3_r;
  reg [33:0] sum0_r, sum1_r;
  reg [33:0] total_sum_r;
  reg [31:0] mean_r;
  reg [31:0] abs0_r, abs1_r, abs2_r, abs3_r;
  reg [31:0] abs_sum0_r, abs_sum1_r;
  reg [31:0] total_abs_sum_r;
  reg [31:0] mad_r;
  reg [3:0] counter;

  function automatic [31:0] absolute(input [31:0] val);
    absolute = val[31] ? (~val + 1) : val;
  endfunction
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      counter <= 0;
      done <= 0;
      num0_r <= 0;
      num1_r <= 0;
      num2_r <= 0;
      num3_r <= 0;
      sum0_r <= 0;
      sum1_r <= 0;
      total_sum_r <= 0;
      mean_r <= 0;
      abs0_r <= 0;
      abs1_r <= 0;
      abs2_r <= 0;
      abs3_r <= 0;
      abs_sum0_r <= 0;
      abs_sum1_r <= 0;
      total_abs_sum_r <= 0;
      mad_r <= 0;
      mad <= 0;
    end 
    else begin
      done <= 0;
      if (counter != 0) counter <= counter + 1;

      if (counter == 10) begin
        counter <= 0;
        done <= 1;
        mad <= mad_r;
      end

      if (start && counter == 0) begin
        counter <= 1;
        num0_r <= num0;
        num1_r <= num1;
        num2_r <= num2;
        num3_r <= num3;
      end

      case (counter)
        1: begin
          sum0_r <= {{2{num0_r[31]}}, num0_r} + {{2{num1_r[31]}}, num1_r};
          sum1_r <= {{2{num2_r[31]}}, num2_r} + {{2{num3_r[31]}}, num3_r};
        end
        2: total_sum_r <= sum0_r + sum1_r;
        3: begin
          automatic logic [33:0] ts = total_sum_r;
          automatic logic [31:0] mean_tmp = ts[33:2];
          automatic logic round_corr = (ts[33] && (|ts[1:0])) ? 1'b1 : 1'b0;
          mean_r <= mean_tmp + round_corr;
        end
        4: begin
          abs0_r <= absolute(num0_r - mean_r);
          abs1_r <= absolute(num1_r - mean_r);
          abs2_r <= absolute(num2_r - mean_r);
          abs3_r <= absolute(num3_r - mean_r);
        end
        5: begin
          abs_sum0_r <= abs0_r + abs1_r;
          abs_sum1_r <= abs2_r + abs3_r;
        end
        6: total_abs_sum_r <= abs_sum0_r + abs_sum1_r;
        7: mad_r <= total_abs_sum_r >> 2; // Division by 4
        default: ;
      endcase
    end
  end
endmodule