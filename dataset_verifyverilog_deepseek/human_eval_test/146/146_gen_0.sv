module special_filter (
  input clk,
  input rst_n,
  input start,
  input signed [15:0] nums [7:0],
  output reg [3:0] count,
  output reg done
);
  
  reg [3:0] cycle_counter;
  reg processing;
  reg [15:0] current_abs_val;
  reg current_abs_gt10;
  reg current_last_odd;
  
  wire [2:0] element_index = cycle_counter[3:1];
  wire phase = cycle_counter[0];
  wire signed [15:0] current_num = nums[element_index];
  wire [15:0] abs_val_combi = (current_num < 0) ? -current_num : current_num;
  
  wire [3:0] first_digit = (current_abs_val >= 16'd10000) ? (current_abs_val / 16'd10000) :
                         (current_abs_val >= 16'd1000) ? (current_abs_val / 16'd1000) :
                         (current_abs_val >= 16'd100)  ? (current_abs_val / 16'd100) :
                         (current_abs_val >= 16'd10)   ? (current_abs_val / 16'd10) : 4'd0;
  wire first_odd = first_digit[0];
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_counter <= 4'd0;
      processing <= 1'b0;
      count <= 4'd0;
      done <= 1'b0;
      current_abs_val <= 16'd0;
      current_abs_gt10 <= 1'b0;
      current_last_odd <= 1'b0;
    end else begin
      if (!processing) begin
        if (start) begin
          processing <= 1'b1;
          cycle_counter <= 4'd0;
          count <= 4'd0;
          done <= 1'b0;
        end
      end else begin
        if (cycle_counter == 4'd15) begin
          processing <= 1'b0;
          done <= 1'b1;
        end else begin
          cycle_counter <= cycle_counter + 4'd1;
        end
        
        if (!phase) begin // Phase 0
          current_abs_val <= abs_val_combi;
          current_abs_gt10 <= (abs_val_combi > 16'd10);
          current_last_odd <= (abs_val_combi > 16'd10) ? ((abs_val_combi % 16'd10) & 1) : 1'b0;
        end else begin // Phase 1
          if (current_abs_gt10 && first_odd && current_last_odd)
            count <= count + 4'd1;
        end
      end
    end
  end
endmodule