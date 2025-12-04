module first_even_odd_diff (
  input signed [7:0] list [0:7],
  output signed [8:0] difference,
  output signed [7:0] first_even,
  output signed [7:0] first_odd
);
  reg signed [7:0] fe;
  reg signed [7:0] fo;
  reg fe_found;
  reg fo_found;
  integer i;

  always @* begin
    fe_found = 1'b0;
    fo_found = 1'b0;
    fe = 8'sb0;
    fo = 8's0;
    for (i = 0; i < 8; i = i + 1) begin
      if (!fe_found && (list[i][0] == 1'b0)) begin
        fe = list[i];
        fe_found = 1'b1;
      end
      if (!fo_found && (list[i][0] == 1'b1)) begin
        fo = list[i];
        fo_found = 1'b1;
      end
    end
    if (!fe_found) fe = 8'sb11111111;  // -1
    if (!fo_found) fo = 8'sb11111111;  // -1
  end

  assign difference = $signed({1'b0, fe}) - $signed({1'b0, fo});
  assign first_even = fe;
  assign first_odd  = fo;
endmodule
