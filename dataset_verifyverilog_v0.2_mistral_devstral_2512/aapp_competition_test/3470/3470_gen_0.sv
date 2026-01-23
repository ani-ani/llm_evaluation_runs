module minesweeper_safe(
  input [2:0] n,
  output [3:0] count,
  output [15:0] safe_mask
);

  reg [3:0] count_reg;
  reg [15:0] safe_mask_reg;

  always @* begin
    case (n)
      3'd1: begin
        count_reg = 4'd0;
        safe_mask_reg = 16'd0;
      end
      3'd2: begin
        count_reg = 4'd4;
        safe_mask_reg = 16'h00AA;
      end
      3'd3: begin
        count_reg = 4'd8;
        safe_mask_reg = 16'hAAAA;
      end
      default: begin
        count_reg = 4'd0;
        safe_mask_reg = 16'd0;
      end
    endcase
  end

  assign count = count_reg;
  assign safe_mask = safe_mask_reg;

endmodule