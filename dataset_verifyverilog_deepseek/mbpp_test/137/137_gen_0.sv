module zero_ratio(input clk, input rst_n, input start, input [7:0] array [0:7],
    output reg [15:0] ratio, output reg done, output reg error);
  
  reg [3:0] counter;
  reg [3:0] zeros_count;
  reg [3:0] non_zeros_count;
  reg start_prev;
  wire start_rise = start && !start_prev;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      counter <= 4'd0;
      zeros_count <= 4'd0;
      non_zeros_count <= 4'd0;
      done <= 1'b0;
      error <= 1'b0;
      ratio <= 16'd0;
      start_prev <= 1'b0;
    end
    else begin
      start_prev <= start;
      if (start_rise && !done) begin
        counter <= 4'd0;
        zeros_count <= 4'd0;
        non_zeros_count <= 4'd0;
        done <= 1'b0;
        error <= 1'b0;
        ratio <= 16'd0;
      end
      else if (counter < 4'd8) begin
        if (array[counter] == 8'd0)
          zeros_count <= zeros_count + 4'd1;
        else
          non_zeros_count <= non_zeros_count + 4'd1;
        counter <= counter + 4'd1;
      end
      else if (counter == 4'd8) begin
        if (non_zeros_count == 4'd0) begin
          error <= 1'b1;
          ratio <= 16'd0;
        end
        else
          ratio <= (zeros_count << 8) / non_zeros_count;
        done <= 1'b1;
        counter <= counter + 4'd1;
      end
      else if (start_rise) begin
        counter <= 4'd0;
        zeros_count <= 4'd0;
        non_zeros_count <= 4'd0;
        done <= 1'b0;
        error <= 1'b0;
        ratio <= 16'd0;
      end
    end
  end
endmodule