module max_diff_calculator (
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] arr,
  output reg [8:0] max_diff,
  output reg done
);

  reg [2:0] counter;
  reg processing;
  reg signed [7:0] min;
  reg signed [7:0] max;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      processing <= 1'b0;
      done <= 1'b0;
      counter <= 3'd0;
      min <= 8'sd0;
      max <= 8'sd0;
      max_diff <= 9'd0;
    end else begin
      done <= 1'b0;
      
      if (processing) begin
        if (counter < 3'd7) begin
          counter <= counter + 3'd1;
          if ($signed(arr[counter]) < min) min <= $signed(arr[counter]);
          if ($signed(arr[counter]) > max) max <= $signed(arr[counter]);
        end else begin
          max_diff <= $unsigned(max - min);
          done <= 1'b1;
          processing <= 1'b0;
          counter <= 3'd0;
        end
      end else if (start) begin
        processing <= 1'b1;
        min <= $signed(arr[0]);
        max <= $signed(arr[0]);
        counter <= 3'd1;
      end
    end
  end

endmodule