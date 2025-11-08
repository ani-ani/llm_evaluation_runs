module TopModule(
  input clk,
  input reset,
  input [2:0] s,
  output reg fr2,
  output reg fr1,
  output reg fr0,
  output reg dfr
);

  reg [2:0] prev_s;
  reg was_rising;

  function int get_level(input logic [2:0] s_in);
    if (s_in[2]) return 3;
    else if (s_in[1]) return 2;
    else if (s_in[0]) return 1;
    else return 0;
  endfunction

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      prev_s <= 3'b000;
      was_rising <= 1'b0;
      fr2 <= 1'b1;
      fr1 <= 1'b1;
      fr0 <= 1'b1;
      dfr <= 1'b1;
    end else begin
      prev_s <= s;
      if (s != prev_s) begin
        logic curr_level = get_level(s);
        logic prev_level = get_level(prev_s);
        if (curr_level > prev_level) was_rising <= 1'b1;
        else if (curr_level < prev_level) was_rising <= 1'b0;
      end
      // compute outputs
      case (s)
        3'b000: begin fr2 = 1'b1; fr1 = 1'b1; fr0 = 1'b1; dfr = 1'b0; end
        3'b001: begin fr2 = 1'b0; fr1 = 1'b1; fr0 = 1'b1; dfr = was_rising; end
        3'b011: begin fr2 = 1'b0; fr1 = 1'b0; fr0 = 1'b1; dfr = was_rising; end
        default: begin fr2 = 1'b0; fr1 = 1'b0; fr0 = 1'b0; dfr = 1'b0; end
      endcase
    end
  end

endmodule