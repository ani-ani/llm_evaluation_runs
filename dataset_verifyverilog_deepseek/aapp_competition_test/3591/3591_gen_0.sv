module photo_filter(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [15:0] heights [0:15],
  output reg valid,
  output reg processing
);

  reg [3:0] counter;
  reg [15:0] max_right_arr [0:15];
  reg [15:0] max_right_reg;
  reg [15:0] max_left_reg;
  reg found;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      counter <= 4'd0;
      processing <= 1'b0;
      valid <= 1'b0;
      found <= 1'b0;
      max_right_reg <= 16'd0;
      max_left_reg <= 16'd0;
      for (int i=0; i<16; i++) max_right_arr[i] <= 16'd0;
    end
    else begin
      if (start) begin
        counter <= 4'd0;
        processing <= 1'b1;
        valid <= 1'b0;
        found <= 1'b0;
        max_right_reg <= 16'd0;
        max_left_reg <= 16'd0;
      end
      else if (processing) begin
        if (counter < 4'd15) begin
          counter <= counter + 4'd1;
          if (counter < n) begin
            // Update max_right array in reverse
            max_right_arr[n-1-counter] <= max_right_reg;
            if (heights[n-1-counter] > max_right_reg) begin
              max_right_reg <= heights[n-1-counter];
            end
            
            // Update max_left and check condition
            if (counter == 4'd0) begin
              max_left_reg <= 16'd0;
            end
            else begin
              if (heights[counter-1] > max_left_reg) begin
                max_left_reg <= heights[counter-1];
              end
              if (max_left_reg > heights[counter] && max_right_arr[counter] > max_left_reg) begin
                found <= 1'b1;
              end
            end
          end
        end
        else begin
          // Final check at cycle 15
          if (max_left_reg > heights[counter] && max_right_arr[counter] > max_left_reg) begin
            found <= 1'b1;
          end
          valid <= found;
          processing <= 1'b0;
        end
      end
    end
  end
endmodule