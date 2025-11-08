module TopModule (
  input clk,
  input reset,
  input [2:0] s,
  output reg fr2,
  output reg fr1,
  output reg fr0,
  output reg dfr
);
  reg [2:0] prev_s;
  wire [1:0] current_level;
  wire [1:0] prev_level;

  assign current_level = (s == 3'b111) ? 2'd3 :
                         (s == 3'b011) ? 2'd2 :
                         (s == 3'b001) ? 2'd1 : 2'd0;
  assign prev_level = (prev_s == 3'b111) ? 2'd3 :
                      (prev_s == 3'b011) ? 2'd2 :
                      (prev_s == 3'b001) ? 2'd1 : 2'd0;

  always_ff @(posedge clk) begin
    if (reset) begin
      prev_s <= 3'b000;
    end else begin
      if (s != prev_s) prev_s <= s;
    end
  end

  always_comb begin
    if (reset) begin
      fr0 = 1'b1;
      fr1 = 1'b1;
      fr2 = 1'b1;
      dfr = 1'b1;
    end else begin
      fr0 = (current_level != 2'd3);
      fr1 = (current_level == 2'd0 || current_level == 2'd1);
      fr2 = (current_level == 2'd0);
      dfr = ((current_level == 2'd1 || current_level == 2'd2) && (current_level > prev_level));
    end
  end
endmodule