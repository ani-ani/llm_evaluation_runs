module count_numbers(
  input  [3:0] n,
  output logic [47:0] count
);
  always_comb begin
    case (n)
      4'd1:  count = 48'd1;
      4'd2:  count = 48'd18;
      4'd3:  count = 48'd180;
      4'd4:  count = 48'd1800;
      4'd5:  count = 48'd18000;
      4'd6:  count = 48'd180000;
      4'd7:  count = 48'd1800000;
      4'd8:  count = 48'd18000000;
      4'd9:  count = 48'd180000000;
      4'd10: count = 48'd1800000000;
      4'd11: count = 48'd18000000000;
      4'd12: count = 48'd180000000000;
      4'd13: count = 48'd1800000000000;
      4'd14: count = 48'd18000000000000;
      4'd15: count = 48'd180000000000000;
      default: count = 48'd0;
    endcase
  end
endmodule