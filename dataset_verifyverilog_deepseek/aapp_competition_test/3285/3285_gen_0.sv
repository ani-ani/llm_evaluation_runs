module sds_finder(
  input clk,
  input rst_n,
  input start,
  input [6:0] r,
  input [7:0] m,
  output reg [4:0] n,
  output reg done
);

  reg [7:0] A_current;
  reg [255:0] used_values;
  reg [255:0] used_diffs;
  reg [4:0] current_step;
  reg computation_active;

  function [7:0] find_first_available(input [255:0] data, input [7:0] max_d);
    integer i;
    begin
      find_first_available = 8'd0;
      for (i = 1; (i <= max_d) && (i < 256); i = i + 1) begin
        if (data[i]) begin
          find_first_available = i;
          break;
        end
      end
    end
  endfunction

  reg [255:0] new_diffs;
  reg [7:0] A_next;
  reg [7:0] d_val;

  always @* begin
    new_diffs = 0;
    for (integer i = 0; i < 256; i++) begin
      if (used_values[i]) begin
        if (A_next > i)
          new_diffs[A_next - i] = 1'b1;
        else
          new_diffs[i - A_next] = 1'b1;
      end
    end
  end

  always @* begin
    d_val = 0;
    A_next = A_current;
    if (computation_active && ~done) begin
      if (~(used_values[m] || used_diffs[m])) begin
        d_val = find_first_available(~(used_values | used_diffs) & ~256'h1, 255 - A_current);
        A_next = A_current + d_val;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      A_current <= 0;
      used_values <= 0;
      used_diffs <= 0;
      current_step <= 0;
      done <= 0;
      computation_active <= 0;
      n <= 0;
    end else begin
      if (start && ~computation_active) begin
        A_current <= r;
        used_values <= (1'b1 << r);
        used_diffs <= 0;
        current_step <= 1;
        done <= 0;
        computation_active <= 1;
      end else if (computation_active && ~done) begin
        if (used_values[m] || used_diffs[m]) begin
          n <= current_step;
          done <= 1;
          computation_active <= 0;
        end else if (current_step < 16) begin
          A_current <= A_next;
          used_values <= used_values | (1'b1 << A_next);
          used_diffs <= used_diffs | new_diffs;
          current_step <= current_step + 1;
        end else begin
          n <= 16;
          done <= 1;
          computation_active <= 0;
        end
      end
    end
  end
endmodule