module pluck (
  input reg [7:0] nodes [0:7],
  output reg [7:0] value,
  output reg [2:0] index,
  output reg valid
);
  always @(*) begin
    value = 8'hFF;
    index = 0;
    valid = 0;
    for (int i = 0; i < 8; i++) begin
      if (nodes[i][0] == 1'b0) begin // Check for even
        if (nodes[i] < value) begin
          value = nodes[i];
          index = i;
          valid = 1;
        end
      end
    end
  end
endmodule