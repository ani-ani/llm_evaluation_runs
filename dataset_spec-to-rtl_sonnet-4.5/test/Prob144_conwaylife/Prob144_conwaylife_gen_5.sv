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
        wire [7:0] n;
        
        // Calculate neighbor indices with wrapping
        localparam int row_prev = (i == 0) ? 15 : i - 1;
        localparam int row_next = (i == 15) ? 0 : i + 1;
        localparam int col_prev = (j == 0) ? 15 : j - 1;
        localparam int col_next = (j == 15) ? 0 : j + 1;
        
        // Get all 8 neighbors
        assign n[0] = q[row_prev * 16 + col_prev];
        assign n[1] = q[row_prev * 16 + j];
        assign n[2] = q[row_prev * 16 + col_next];
        assign n[3] = q[i * 16 + col_prev];
        assign n[4] = q[i * 16 + col_next];
        assign n[5] = q[row_next * 16 + col_prev];
        assign n[6] = q[row_next * 16 + j];
        assign n[7] = q[row_next * 16 + col_next];
        
        // Count neighbors
        assign sum = n[0] + n[1] + n[2] + n[3] + n[4] + n[5] + n[6] + n[7];
        assign neighbor_count = sum[3:0];
        
        // Apply game rules
        assign next_q[i * 16 + j] = (neighbor_count == 4'd2) ? q[i * 16 + j] :
                                     (neighbor_count == 4'd3) ? 1'b1 :
                                     1'b0;
      end
    end
  endgenerate
  
  // Update state on clock edge
  always @(posedge clk) begin
    if (load)
      q <= data;
    else
      q <= next_q;
  end

endmodule