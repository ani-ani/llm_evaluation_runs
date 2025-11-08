module TopModule(input clk, input load, input [511:0] data, output reg [511:0] q);
  function bit rule110(input bit left, input bit center, input bit right);
    case ({left, center, right})
      3'b000, 3'b100, 3'b111: rule110 = 0;
      default: rule110 = 1;
    endcase
  endfunction

  logic [511:0] next_q;
  always_comb begin
    for (int i = 0; i < 512; i++) begin
      bit left_bit = (i == 511) ? 1'b0 : q[i+1];
      bit right_bit = (i == 0) ? 1'b0 : q[i-1];
      next_q[i] = rule110(left_bit, q[i], right_bit);
    end
  end

  always_ff @(posedge clk) begin
    if (load)
      q <= data;
    else
      q <= next_q;
  end
endmodule