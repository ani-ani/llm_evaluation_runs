module first_even_odd_diff(
  input  signed [7:0] list [0:7],
  output signed [8:0] difference
);

  integer i;
  reg signed [7:0] first_even;
  reg signed [7:0] first_odd;
  reg found_even;
  reg found_odd;

  always @* begin
    first_even = -8'sd1; // default if no even found
    first_odd  = -8'sd1; // default if no odd found
    found_even = 1'b0;
    found_odd  = 1'b0;

    for (i = 0; i < 8; i = i + 1) begin
      if (!found_even && (list[i][0] == 1'b0)) begin
        first_even = list[i];
        found_even = 1'b1;
      end
      if (!found_odd && (list[i][0] == 1'b1)) begin
        first_odd = list[i];
        found_odd = 1'b1;
      end
    end
  end

  assign difference = {first_even[7], first_even} - {first_odd[7], first_odd};

endmodule