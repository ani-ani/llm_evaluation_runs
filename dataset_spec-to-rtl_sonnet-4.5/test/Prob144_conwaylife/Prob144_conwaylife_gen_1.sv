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
        
        // Calculate neighbor indices with wrapping
        wire [3:0] i_up = (i == 0) ? 4'd15 : i - 1;
        wire [3:0] i_down = (i == 15) ? 4'd0 : i + 1;
        wire [3:0] j_left = (j == 0) ? 4'd15 : j - 1;
        wire [3:0] j_right = (j == 15) ? 4'd0 : j + 1;
        
        // Calculate linear indices for all 8 neighbors
        wire [7:0] idx_ul = {i_up, j_left};
        wire [7:0] idx_u = {i_up, j[3:0]};
        wire [7:0] idx_ur = {i_up, j_right};
        wire [7:0] idx_l = {i[3:0], j_left};
        wire [7:0] idx_r = {i[3:0], j_right};
        wire [7:0] idx_dl = {i_down, j_left};
        wire [7:0] idx_d = {i_down, j[3:0]};
        wire [7:0] idx_dr = {i_down, j_right};
        
        // Sum all 8 neighbors
        assign sum = q[idx_ul] + q[idx_u] + q[idx_ur] + 
                     q[idx_l] + q[idx_r] + 
                     q[idx_dl] + q[idx_d] + q[idx_dr];
        
        assign neighbor_count = sum[3:0];
        
        // Current cell index
        wire [7:0] idx_curr = {i[3:0], j[3:0]};
        
        // Game of Life rules
        assign next_q[idx_curr] = (neighbor_count == 4'd2) ? q[idx_curr] :
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