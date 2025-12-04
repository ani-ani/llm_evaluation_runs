module common_index_elements (
  input [7:0] l1 [0:7],
  input [7:0] l2 [0:7],
  input [7:0] l3 [0:7],
  output reg [7:0] result [0:7],
  output reg [3:0] count
);

  reg [3:0] pos [0:8];
  integer i;

  always_comb begin
    pos[0] = 0;
    for (i = 0; i < 8; i = i + 1) begin
      result[i] = 8'b0;
      pos[i+1] = pos[i] + ( (l1[i] == l2[i]) && (l2[i] == l3[i]) );
    end
    for (i = 0; i < 8; i = i + 1) begin
      if ( (l1[i] == l2[i]) && (l2[i] == l3[i]) ) begin
        result[ pos[i] ] = l1[i];
      end
    end
    count = pos[8];
  end

endmodule