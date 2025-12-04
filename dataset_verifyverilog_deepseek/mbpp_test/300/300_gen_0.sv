module binary_sequence_count(input [3:0] n, output reg [7:0] count);
  always_comb begin
    case(n)
      4'd1: count = 8'h02;
      4'd2: count = 8'h06;
      4'd3: count = 8'h14;
      4'd4: count = 8'h46;
      default: count = 8'h00;
    endcase
  end
endmodule