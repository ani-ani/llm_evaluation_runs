module TopModule(
  input  reg clk,
  input  reg reset,
  input  reg [2:0] s,
  output reg fr2,
  output reg fr1,
  output reg fr0,
  output reg dfr
);
  reg [1:0] prev_level;
  reg dfr_reg;

  always_ff @(posedge clk) begin
    if (reset) begin
      prev_level <= 2'b00;
      dfr_reg <= 1'b1;
    end else begin
      reg [1:0] current_level;
      if (s[2])
        current_level = 2'b11;
      else if (s[1])
        current_level = 2'b10;
      else if (s[0])
        current_level = 2'b01;
      else
        current_level = 2'b00;
      
      if (current_level != prev_level) begin
        if (current_level > prev_level)
          dfr_reg <= 1'b1;
        else if (current_level < prev_level)
          dfr_reg <= 1'b0;
      end
      prev_level <= current_level;
    end
  end

  assign dfr = dfr_reg;

  always_comb begin
    reg [1:0] current_level_comb;
    if (s[2])
      current_level_comb = 2'b11;
    else if (s[1])
      current_level_comb = 2'b10;
    else if (s[0])
      current_level_comb = 2'b01;
    else
      current_level_comb = 2'b00;
    
    case (current_level_comb)
      2'b00: {fr2, fr1, fr0} = 3'b111;
      2'b01: {fr2, fr1, fr0} = 3'b011;
      2'b10: {fr2, fr1, fr0} = 3'b001;
      2'b11: {fr2, fr1, fr0} = 3'b000;
      default: {fr2, fr1, fr0} = 3'b000;
    endcase
  end

endmodule