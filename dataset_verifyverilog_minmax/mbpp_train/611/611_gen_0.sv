module max_nth_column(
  input wire [1:0] col_idx,
  input reg [4:0] row0 [2:0],
  input reg [4:0] row1 [2:0],
  input reg [4:0] row2 [2:0],
  output reg [4:0] max_val
);
  // Local wires for the three column values
  wire [4:0] c0, c1, c2;

  // 1) Select each row's element from the selected column (combinational mux)
  assign c0 = (col_idx == 2'b00) ? row0[0] :
              (col_idx == 2'b01) ? row0[1] :
              row0[2];

  assign c1 = (col_idx == 2'b00) ? row1[0] :
              (col_idx == 2'b01) ? row1[1] :
              row1[2];

  assign c2 = (col_idx == 2'b00) ? row2[0] :
              (col_idx == 2'b01) ? row2[1] :
              row2[2];

  // 2) Compare the three selected elements in parallel
  // 3) Output the maximum value combinatorially
  always @(*) begin
    max_val = c0;
    if (c1 > max_val) max_val = c1;
    if (c2 > max_val) max_val = c2;
  end

endmodule