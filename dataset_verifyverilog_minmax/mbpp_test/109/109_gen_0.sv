module odd_equivalent (
  input  reg [7:0] s,   // 8-bit binary string (padded with leading zeros if needed)
  input  reg [2:0] n,   // Rotation count (0-7)
  output  reg [3:0] count // Number of rotations where LSB is '1'
);

  // Duplicate the input to allow easy circular right-rotation access via indexing
  wire [15:0] dup = {s, s};

  integer i;
  reg [3:0] cnt;

  // Single-cycle (combinational) computation
  always @(*) begin
    cnt = 4'd0;
    for (i = 0; i < 8; i = i + 1) begin
      if (i < n) begin
        // After i cyclic right rotations, the LSB is dup[7+i][0]
        if (dup[7 + i][0]) cnt = cnt + 1;
      end
    end
    count = cnt;
  end

endmodule