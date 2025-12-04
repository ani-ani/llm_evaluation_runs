module min_max_finder (
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] data_in,
  output reg signed [7:0] a,
  output reg signed [7:0] b,
  output reg done
);

  reg [2:0] counter;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a <= 8'd128;
      b <= 8'd127;
      done <= 1'b0;
      counter <= 3'd0;
    end else begin
      if (start) begin
        a <= 8'd128;
        b <= 8'd127;
        done <= 1'b0;
        counter <= 3'd0;
      end else if (counter < 3'd7) begin
        if (data_in[counter] < 0) begin
          if (a == 8'd128 || data_in[counter] > a) begin
            a <= data_in[counter];
          end
        end
        if (data_in[counter] > 0) begin
          if (b == 8'd127 || data_in[counter] < b) begin
            b <= data_in[counter];
          end
        end
        counter <= counter + 1;
      end else if (counter == 3'd7) begin
        if (data_in[counter] < 0) begin
          if (a == 8'd128 || data_in[counter] > a) begin
            a <= data_in[counter];
          end
        end
        if (data_in[counter] > 0) begin
          if (b == 8'd127 || data_in[counter] < b) begin
            b <= data_in[counter];
          end
        end
        done <= 1'b1;
        counter <= 3'd0;
      end
    end
  end

endmodule