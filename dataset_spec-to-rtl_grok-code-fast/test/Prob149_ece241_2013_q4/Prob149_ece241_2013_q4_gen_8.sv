module TopModule(
  input wire clk,
  input wire reset,
  input wire [2:0] s,
  output wire fr2,
  output wire fr1,
  output wire fr0,
  output wire dfr
);
  reg [1:0] prev_level;
  reg dfr_reg;
  reg [2:0] prev_s;

  wire [1:0] level;
  assign fr0 = (level < 2'd3) ? 1'b1 : 1'b0;
  assign fr1 = (level <= 2'd1) ? 1'b1 : 1'b0;
  assign fr2 = (level == 2'd0) ? 1'b1 : 1'b0;
  assign dfr = (level == 2'd0) | ((level == 2'd1 | level == 2'd2) & dfr_reg);

  always_comb begin
    case(s)
      3'b111: level = 2'd3;
      3'b011: level = 2'd2;
      3'b001: level = 2'd1;
      default: level = 2'd0;
    endcase
  end

  always @(posedge clk) begin
    if(reset) begin
      prev_level <= 2'd0;
      dfr_reg <= 1'b1;
      prev_s <= 3'b000;
    end else begin
      if(s != prev_s) begin
        prev_s <= s;
        if((level > prev_level) && (level == 2'd1 || level == 2'd2)) begin
          dfr_reg <= 1'b1;
        end else begin
          dfr_reg <= 1'b0;
        end
        prev_level <= level;
      end
    end
  end
endmodule