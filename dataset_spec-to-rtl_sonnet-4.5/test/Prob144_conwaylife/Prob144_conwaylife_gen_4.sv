module TopModule(
  input clk,
  input load,
  input [255:0] data,
  output reg [255:0] q
);

  wire [255:0] next_q;
  
  genvar i, j;
  generate
    for (i = 0; i < 16; i = i + 1) begin : row
      for (j = 0; j < 16; j = j + 1) begin : col
        wire [3:0] neighbor_count;
        wire [4:0] sum;
        wire up, down, left, right;
        wire up_left, up_right, down_left, down_right;
        
        // Calculate wrapped indices
        localparam up_i = (i == 0) ? 15 : i - 1;
        localparam down_i = (i == 15) ? 0 : i + 1;
        localparam left_j = (j == 0) ? 15 : j - 1;
        localparam right_j = (j == 15) ? 0 : j + 1;
        
        // Get neighbor values
        assign up = q[up_i * 16 + j];
        assign down = q[down_i * 16 + j];
        assign left = q[i * 16 + left_j];
        assign right = q[i * 16 + right_j];
        assign up_left = q[up_i * 16 + left_j];
        assign up_right = q[up_i * 16 + right_j];
        assign down_left = q[down_i * 16 + left_j];
        assign down_right = q[down_i * 16 + right_j];
        
        // Count neighbors
        assign sum = up + down + left + right + up_left + up_right + down_left + down_right;
        assign neighbor_count = sum[3:0];
        
        // Determine next state based on rules
        assign next_q[i * 16 + j] = (neighbor_count == 4'd2) ? q[i * 16 + j] :
                                     (neighbor_count == 4'd3) ? 1'b1 : 1'b0;
      end
    end
  endgenerate
  
  // Sequential logic
  always @(posedge clk) begin
    if (load)
      q <= data;
    else
      q <= next_q;
  end

endmodule