module pluck(
  input [7:0] nodes [0:7],
  output reg [7:0] value,
  output reg [2:0] index,
  output reg valid
);
  always_comb begin
    bit found = 1'b0;
    logic [7:0] min_val = 8'hFF;
    logic [2:0] min_idx = 3'b0;
    
    for (int i=0; i<8; i++) begin
      if (nodes[i][0] == 1'b0) begin
        if (!found || (nodes[i] < min_val)) begin
          min_val = nodes[i];
          min_idx = i;
          found = 1'b1;
        end
      end
    end
    
    valid = found;
    if (found) begin
      value = min_val;
      index = min_idx;
    end else begin
      value = '0;
      index = '0;
    end
  end
endmodule