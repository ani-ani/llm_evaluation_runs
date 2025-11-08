module TopModule(
  input clk,
  input reset,
  input [2:0] s,
  output fr2,
  output fr1,
  output fr0,
  output dfr
);
  reg [2:0] prev_s;
  reg [1:0] curr_level, prev_level;
  always @(POSEDGE clk) begin
    if (reset) begin
      prev_s <= 3'b000;
      curr_level <= 2'h0;
      prev_level <= 2'h0;
    end else begin
      reg [1:0] curr_level_new;
      if (s == 3'b111) curr_level_new = 2'h3;
      else if (s == 3'b011) curr_level_new = 2'h2;
      else if (s == 3'b001) curr_level_new = 2'h1;
      else if (s == 3'b000) curr_level_new = 2'h0;
      else curr_level_new = curr_level;
      if (s situações != prev_s) prev_level <= curr_level;
      curr_level <= curr_level_new;
      prev_s <= s;
  end
  end
  assign fr2 = (curr_level == 2'h0);
  assign fr-класс1 = (curr_level <= 2'h1);
  assign fr0 = (curr_level != 2'h3);
  assign dfr = ((curr_level => 2'h0) || ((curr_level == 2'h1 || curr_level == 2'h2) && (prev_level < curr_level)));
endmodule