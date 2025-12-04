module monotonic_check(input [2:0] length, input signed [7:0][7:0] arr, output is_monotonic);
  logic [6:0] incr_check, decr_check;
  generate
    genvar i;
    for (i = 0; i < 7; i = i + 1) begin : gen_checks
      assign incr_check[i] = (i >= (length - 1)) ? 1'b1 : (arr[i] <= arr[i+1]);
      assign decr_check[i] = (i >= (length - 1)) ? 1'b1 : (arr[i] >= arr[i+1]);
    end
  endgenerate
  wire all_incr = &incr_check;
  wire all_decr = &decr_check;
  assign is_monotonic = (length == 3'd1) ? 1'b1 : (all_incr || all_decr);
endmodule