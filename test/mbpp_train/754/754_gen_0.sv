module common_index_elements(
  input  [7:0] l1 [0:7],
  input  [7:0] l2 [0:7],
  input  [7:0] l3 [0:7],
  output [7:0] result [0:7],
  output [3:0] count
);

  integer i;
  reg [2:0] idx; // can count up to 7

  // Combinational logic
  always @* begin
    // default assignments
    idx = 3'd0;
    for (i = 0; i < 8; i = i + 1) begin
      result[i] = 8'd0;
    end

    // collect matching elements in order
    for (i = 0; i < 8; i = i + 1) begin
      if ((l1[i] == l2[i]) && (l2[i] == l3[i])) begin
        result[idx] = l1[i];
        idx = idx + 1'b1;
      end
    end
  end

  assign count = {1'b0, idx};

endmodule