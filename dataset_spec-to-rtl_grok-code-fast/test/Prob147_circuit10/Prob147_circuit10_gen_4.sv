module TopModule(input clk, a, b, output q, state);
  reg [3:0] cnt = 4'b0000;
  reg st = 1'b0;
  wire a_b = a ^ b;
  assign q = st ? ~a_b : a_b;
  assign state = st;
  always_ff @(posedge clk) begin
    if (cnt == 7 || cnt == 9) st <= ~st;
    else if (cnt == 8 || cnt == 14) st <= ~st;
    cnt <= cnt + 1;
  end
endmodule