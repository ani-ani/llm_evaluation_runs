module min_subarray_sum(
  input clk,
  input rst_n,
  input start,
  input reg [7:0][15:0] nums,
  output reg [15:0] min_sum,
  output reg done
);

  reg [3:0] counter;
  reg [15:0] current_min, global_min;
  reg start_prev;
  reg compute_en;

  always @(posedge clk) begin
    if (!rst_n) begin
      min_sum <= 0;
      done <= 0;
      compute_en <= 0;
      counter <= 0;
      start_prev <= 0;
      current_min <= 0;
      global_min <= 0;
    end else begin
      start_prev <= start;
      if (compute_en) begin
        if (counter < 9) begin
          counter <= counter + 1;
        end
        if (counter == 9) begin
          done <= 1;
        end
        case (counter)
          4'b0000: begin
            current_min <= nums[0];
            global_min <= nums[0];
          end
          4'b0001: begin
            // Initialization cycle 2, no action
          end
          4'b0010, 4'b0011, 4'b0100, 4'b0101, 4'b0110, 4'b0111, 4'b1000: begin
            current_min <= ($signed(current_min) + $signed(nums[counter-1])) < $signed(nums[counter-1]) ? ($signed(current_min) + $signed(nums[counter-1])) : $signed(nums[counter-1]);
            global_min <= $signed(global_min) < $signed(current_min) ? $signed(global_min) : $signed(current_min);
          end
          4'b1001: begin
            min_sum <= global_min;
          end
        endcase
      end else begin
        done <= 0;
        if (start && !start_prev) begin
          compute_en <= 1;
          counter <= 0;
          current_min <= 0;
          global_min <= 0;
        end
      end
    end
  end

endmodule