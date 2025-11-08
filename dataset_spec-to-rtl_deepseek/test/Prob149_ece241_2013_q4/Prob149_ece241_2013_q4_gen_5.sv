module TopModule(input clk, input reset, input [2:0] s, output fr2, output fr1, output fr0, output dfr);
  localparam [1:0] BELOW_S0 = 2'b00;
  localparam [1:0] BETWEEN_S1_S0 = 2'b01;
  localparam [1:0] BETWEEN_S2_S1 = 2'b10;
  localparam [1:0] ABOVE_S2 = 2'b11;
  reg [1:0] prev_level;
  wire [1:0] current_level = (s == 3'b111) ? ABOVE_S2 :
                             (s == 3'b011) ? BETWEEN_S2_S1 :
                             (s == 3'b001) ? BETWEEN_S1_S0 :
                             BELOW_S0;
  always_ff @(posedge clk) begin
    if (reset)
      prev_level <= BELOW_S0;
    else
      prev_level <= current_level;
  end
  assign fr0 = reset ? 1'b1 : (current_level != ABOVE_S2);
  assign fr1 = reset ? 1'b1 : (current_level == BETWEEN_S1_S0 || current_level == BELOW_S0);
  assign fr2 = reset ? 1'b1 : (current_level == BELOW_S0);
  assign dfr = reset ? 1'b1 : (current_level > prev_level);
endmodule