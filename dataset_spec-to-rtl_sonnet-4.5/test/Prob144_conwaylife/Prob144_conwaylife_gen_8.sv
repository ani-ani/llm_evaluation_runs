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
        wire current_cell;
        wire next_cell;
        
        wire [3:0] row_up = (i == 0) ? 4'd15 : i - 1;
        wire [3:0] row_down = (i == 15) ? 4'd0 : i + 1;
        wire [3:0] col_left = (j == 0) ? 4'd15 : j - 1;
        wire [3:0] col_right = (j == 15) ? 4'd0 : j + 1;
        
        assign current_cell = q[i*16 + j];
        
        assign sum = q[row_up*16 + col_left] +
                     q[row_up*16 + j] +
                     q[row_up*16 + col_right] +
                     q[i*16 + col_left] +
                     q[i*16 + col_right] +
                     q[row_down*16 + col_left] +
                     q[row_down*16 + j] +
                     q[row_down*16 + col_right];
        
        assign neighbor_count = sum[3:0];
        
        assign next_cell = (neighbor_count == 4'd2) ? current_cell :
                          (neighbor_count == 4'd3) ? 1'b1 :
                          1'b0;
        
        assign next_q[i*16 + j] = next_cell;
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