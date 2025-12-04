module max_pair_diff (
  input clk,
  input rst_n,
  input [7:0][5:0] pairs,
  input start,
  output reg [5:0] max_diff,
  output reg done
);

  reg [2:0] counter_d;
  reg [5:0] max_diff_d;
  reg processing_d;
  wire [2:0] counter_next = counter_d + 1'b1;
  
  wire [5:0] a_vals [7:0];
  wire [5:0] b_vals [7:0];
  
  generate
    genvar i;
    for (i=0; i<8; i=i+1) begin : split_pairs
      assign a_vals[i] = pairs[i][5:0];
      assign b_vals[i] = pairs[i+8][5:0];
    end
  endgenerate
  
  wire [5:0] curr_diff = (a_vals[counter_d] >= b_vals[counter_d]) ? 
                         (a_vals[counter_d] - b_vals[counter_d]) : 
                         (b_vals[counter_d] - a_vals[counter_d]);
  
  wire [5:0] new_max = (curr_diff > max_diff_d) ? curr_diff : max_diff_d;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      counter_d <= 3'b0;
      max_diff_d <= 6'b0;
      done <= 1'b0;
      processing_d <= 1'b0;
    end else begin
      if (start) begin
        counter_d <= 3'b0;
        max_diff_d <= 6'b0;
        processing_d <= 1'b1;
        done <= 1'b0;
      end else if (processing_d) begin
        if (counter_d == 3'd7) begin
          max_diff <= new_max;
          done <= 1'b1;
          processing_d <= 1'b0;
          counter_d <= 3'b0;
        end else begin
          counter_d <= counter_next;
          max_diff_d <= new_max;
          done <= 1'b0;
        end
      end else begin
        done <= 1'b0;
      end
    end
  end

endmodule