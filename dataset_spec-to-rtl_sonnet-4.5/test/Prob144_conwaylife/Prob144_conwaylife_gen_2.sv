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
        
        wire up = (i == 0) ? 15 : i - 1;
        wire down = (i == 15) ? 0 : i + 1;
        wire left = (j == 0) ? 15 : j - 1;
        wire right = (j == 15) ? 0 : j + 1;
        
        wire [7:0] up_idx = up;
        wire [7:0] down_idx = down;
        wire [7:0] left_idx = left;
        wire [7:0] right_idx = right;
        wire [7:0] i_idx = i;
        wire [7:0] j_idx = j;
        
        assign sum = q[up_idx*16 + left_idx] + 
                     q[up_idx*16 + j_idx] + 
                     q[up_idx*16 + right_idx] + 
                     q[i_idx*16 + left_idx] + 
                     q[i_idx*16 + right_idx] + 
                     q[down_idx*16 + left_idx] + 
                     q[down_idx*16 + j_idx] + 
                     q[down_idx*16 + right_idx];
        
        assign neighbor_count = sum[3:0];
        
        assign next_q[i*16 + j] = (neighbor_count == 4'd2) ? q[i*16 + j] :
                                   (neighbor_count == 4'd3) ? 1'b1 : 1'b0;
      end
    end
  endgenerate
  
  always @(posedge clk) begin
    if (load)
      q <= data;
    else
      q <= next_q;
  end

endmodule