module TopModule(
  input clk,
  input reset,
  input [2:0] s,
  output reg fr2,
  output reg fr1,
  output reg fr0,
  output reg dfr
);
  reg [1:0] last_level;
  reg rising_flag;
  reg [1:0] current_level;
  always_ff @(posedge clk) begin
    if (reset) begin
      last_level <= 2'b00;
      rising_flag <= 1'b0;
      fr2 <= 1'b1;
      fr1 <= 1'b1;
      fr0 <= 1'b1;
      dfr <= 1'b0;
    end else begin
      case (s)
        3'b000: current_level = 2'b00;
        3'b001: current_level = 2'b01;
        3'b011: current_level = 2'b10;
        3'b111: current_level = 2'b11;
        default: current_level = 2'b00;
      endcase
      if (current_level > last_level) rising_flag <= 1'b1;
      else if (current_level < last_level) rising_flag <= 1'b0;
      last_level <= current_level;
      case (current_level)
        2'b00: {fr2, fr1, fr0} = 3'b111;
        2'b01: {fr2, fr1, fr0} = 3'b011;
        2'b10: {fr2, fr1, fr0} = 3'b001;
        2'b11: {fr2, fr1, fr0} = 3'b000;
        default: {fr2, fr1, fr0} = 3'b111;
      endcase
      dfr <= (current_level == 2'b01 || current_level == 2'b10) ? rising_flag : 1'b0;
    end
  end
endmodule