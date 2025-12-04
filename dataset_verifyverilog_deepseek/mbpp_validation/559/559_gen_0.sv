module max_subarray_sum (
  input clk,
  input rst_n,
  input start,
  input signed [4:0] a [0:7],
  output reg signed [4:0] max_sum,
  output reg done
);
  reg [3:0] counter;
  reg signed [4:0] max_so_far;
  reg signed [4:0] max_ending_here;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      counter <= 4'd8;
      max_so_far <= 5'sd0;
      max_ending_here <= 5'sd0;
      max_sum <= 5'sd0;
      done <= 1'b0;
    end else begin
      if (start && (counter == 4'd8)) begin
        counter <= 4'd0;
        max_so_far <= 5'sd0;
        max_ending_here <= 5'sd0;
        done <= 1'b0;
      end else if (counter < 4'd8) begin
        counter <= counter + 1;

        if (counter < 4'd8) begin
          automatic logic signed [5:0] temp_sum = max_ending_here + a[counter];
          automatic logic signed [5:0] max_so_far_ext = {max_so_far[4], max_so_far};

          if (temp_sum < 6'sd0) begin
            max_ending_here <= 5'sd0;
          end else begin
            max_ending_here <= temp_sum[4:0];
            if (temp_sum > max_so_far_ext) begin
              max_so_far <= temp_sum[4:0];
            end
          end
        end
      end else if (counter == 4'd8) begin
        max_sum <= max_so_far;
        done <= 1'b1;
      end
    end
  end
endmodule