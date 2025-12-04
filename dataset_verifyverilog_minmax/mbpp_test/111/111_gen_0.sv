module common_in_nested (
  input [5:0] list0 [0:7],
  input [5:0] list1 [0:7],
  input [5:0] list2 [0:7],
  output wire [63:0] common
);

  // Presence masks: bit[i] == 1 if value i (1..63) appears in the list
  logic [63:0] presence0, presence1, presence2;

  // List 0 mask
  always @* begin
    presence0 = 64'b0;
    for (int i = 0; i < 8; i++) begin
      if (list0[i] != 0) begin
        presence0[list0[i]] = 1'b1;
      end
    end
  end

  // List 1 mask
  always @* begin
    presence1 = 64'b0;
    for (int i = 0; i < 8; i++) begin
      if (list1[i] != 0) begin
        presence1[list1[i]] = 1'b1;
      end
    end
  end

  // List 2 mask
  always @* begin
    presence2 = 64'b0;
    for (int i = 0; i < 8; i++) begin
      if (list2[i] != 0) begin
        presence2[list2[i]] = 1'b1;
      end
    end
  end

  // Common elements across all three lists
  assign common = presence0 & presence1 & presence2;

endmodule
