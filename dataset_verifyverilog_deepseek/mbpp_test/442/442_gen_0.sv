module positive_ratio(input clk, rst_n, start, input [3:0] array_size, input signed [15:0] nums[0:15], output reg [15:0] ratio, output reg done);
  reg [4:0] cycle_cnt;
  reg [3:0] index;
  reg [4:0] count;
  reg signed [15:0] nums_reg[0:15];
  reg [3:0] array_size_reg;
  reg busy;
  wire [19:0] numerator;
  wire [15:0] ratio_raw;
  
  assign numerator = (count << 8) + {12'b0, array_size_reg} >> 1;
  assign ratio_raw = (array_size_reg == 4'b0) ? 16'b0 : numerator / {12'b0, array_size_reg};
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      busy <= 1'b0;
      done <= 1'b0;
      ratio <= 16'b0;
      cycle_cnt <= 5'b0;
      index <= 4'b0;
      count <= 5'b0;
      array_size_reg <= 4'b0;
      for (int i = 0; i < 16; i = i + 1) nums_reg[i] <= 16'b0;
    end
    else begin
      if (busy) begin
        cycle_cnt <= cycle_cnt + 1;
        
        if (cycle_cnt < {1'b0, array_size_reg}) begin
          if (nums_reg[index] > 16'sb0) count <= count + 1;
          index <= index + 1;
        end
        
        if (cycle_cnt == {1'b0, array_size_reg}) ratio <= ratio_raw;
        
        if (cycle_cnt == 5'd19) begin
          done <= 1'b1;
          busy <= 1'b0;
        end
        else done <= 1'b0;
      end
      else if (start) begin
        busy <= 1'b1;
        cycle_cnt <= 5'b0;
        index <= 4'b0;
        count <= 5'b0;
        array_size_reg <= array_size;
        for (int i = 0; i < 16; i = i + 1) nums_reg[i] <= nums[i];
        done <= 1'b0;
        ratio <= 16'b0;
      end
      else begin
        done <= 1'b0;
      end
    end
  end
endmodule