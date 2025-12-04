module min_sublist (
  input [3:0] valid_mask [3:0],
  input [7:0] data [3:0][3:0],
  output reg [7:0] min_data [3:0],
  output reg [3:0] out_valid_mask
);
  
  reg [2:0] counts [3:0];
  
  always_comb begin
    // Calculate popcount for each sublist
    for (int i=0; i<4; i++) begin
      counts[i] = valid_mask[i][0] + valid_mask[i][1] + valid_mask[i][2] + valid_mask[i][3];
    end
    
    // Find first minimum count
    reg [2:0] min_val = counts[0];
    int min_idx = 0;
    for (int j=1; j<4; j++) begin
      if (counts[j] < min_val) begin
        min_val = counts[j];
        min_idx = j;
      end
    end
    
    // Assign outputs
    min_data = data[min_idx];
    out_valid_mask = valid_mask[min_idx];
  end

endmodule