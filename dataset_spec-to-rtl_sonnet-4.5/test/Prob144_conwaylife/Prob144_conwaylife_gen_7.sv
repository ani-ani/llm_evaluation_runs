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
        
        // Calculate wrapped indices
        wire [3:0] up = (i == 0) ? 4'd15 : i - 1;
        wire [3:0] down = (i == 15) ? 4'd0 : i + 1;
        wire [3:0] left = (j == 0) ? 4'd15 : j - 1;
        wire [3:0] right = (j == 15) ? 4'd0 : j + 1;
        
        // Count neighbors
        assign sum = q[up*16 + left] + q[up*16 + j] + q[up*16 + right] +
                     q[i*16 + left] + q[i*16 + right] +
                     q[down*16 + left] + q[down*16 + j] + q[down*16 + right];
        
        assign neighbor_count = sum[3:0];
        
        // Apply game rules
        assign next_q[i*16 + j] = (neighbor_count == 4'd2) ? q[i*16 + j] :
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