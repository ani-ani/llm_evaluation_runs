module generate_integers(
  input [7:0] a,
  input [7:0] b,
  output [7:0] result,
  output [7:0] distance
);

  wire [7:0] a_capped = (a > 99) ? 99 : a;
  wire is_even = (a_capped[0] == 0);
  wire [7:0] result_even = a_capped;
  wire [7:0] distance_even = 0;

  wire [7:0] result_odd;
  wire [7:0] distance_odd;

  always_comb begin
    if (a_capped == 0) begin
      result_odd = 2;
      distance_odd = 2;
    end else if (a_capped == 99) begin
      result_odd = 98;
      distance_odd = 1;
    end else begin
      result_odd = a_capped - 1;
      distance_odd = 1;
    end
  end

  assign result = is_even ? result_even : result_odd;
  assign distance = is_even ? distance_even : distance_odd;

endmodule