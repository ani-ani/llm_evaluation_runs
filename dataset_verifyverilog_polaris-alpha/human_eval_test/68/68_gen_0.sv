module pluck(
  input      [7:0] nodes [0:7],
  output reg [7:0] value,
  output reg [2:0] index,
  output reg       valid
);

  integer i;
  reg [7:0] min_val;
  reg [2:0] min_idx;
  reg       found;

  always @* begin
    found   = 1'b0;
    min_val = 8'hFF;      // Initialize to max 8-bit value
    min_idx = 3'b000;

    for (i = 0; i < 8; i = i + 1) begin
      if (nodes[i][0] == 1'b0) begin  // even check
        if (!found || (nodes[i] < min_val)) begin
          found   = 1'b1;
          min_val = nodes[i];
          min_idx = i[2:0];
        end
      end
    end

    valid = found;
    value = min_val;
    index = min_idx;
  end

endmodule