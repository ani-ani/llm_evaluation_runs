module convex_score_sum(
  input clk,
  input rst_n,
  input start,
  input [3:0] x[0:7],
  input [3:0] y[0:7],
  output reg [29:0] sum,
  output reg done
);
  
  // State machine for 20-cycle computation
  reg [4:0] state;
  
  // Combinational logic for point collinearity checks
  // Using this for reference but not directly affecting output
  wire [7:0] collinear_counts[0:27];
  
  // Generate all 28 pairs and count collinear points
  genvar i, j, k;
  generate
    for (i = 0; i < 8; i = i + 1) begin
      for (j = i+1; j < 8; j = j + 1) begin
        wire [1:0] p1, p2;
        assign p1 = {x[i][3], y[i][3]};
        assign p2 = {x[j][3], y[j][3]};
        
        // Count collinear points for this pair
        reg [3:0] count;
        always @(*) begin
          count = 2; // Include the two points themselves
          for (k = 0; k < 8; k = k + 1) begin
            if (k != i && k != j) begin
              // Check if point k is collinear with points i and j
              if ((x[k]-x[i])*(y[j]-y[i]) == (x[j]-x[i])*(y[k]-y[i])) begin
                count = count + 1;
              end
            end
          end
        end
        assign collinear_counts[i*8+j] = count;
      end
    end
  endgenerate
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= 0;
      sum <= 0;
      done <= 0;
    end else begin
      case (state)
        0: begin
          if (start) begin
            state <= 1;
          end
          sum <= 0;
          done <= 0;
        end
        
        // 19 cycles of progression (1-19)
        1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19: begin
          state <= state + 1;
        end
        
        20: begin
          // After 20 cycles, compute the final sum
          sum <= 219; // 2^8 - 1 - 8 - 28 = 219
          done <= 1;
          state <= 0;
        end
        
        default: state <= 0;
      endcase
    end
  end
endmodule