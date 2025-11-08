module TopModule(
  input  clk,
  input  reset,
  input  x,
  output z
);

  reg [2:0] y;
  reg z_out;

  // Next state logic
  always @(posedge clk) begin
    if (reset) begin
      y <= 3'b000;
    end else begin
      case (y)
        3'b000: y <= x ? 3'b001 : 3'b000;
        3'b001: y <= x ? 3'b100 : 3'b001;
        3'b010: y <= x ? 3'b001 : 3'b010;
        3'b011: y <= x ? 3'b010 : 3'b001;
        3'b100: y <= x ? 3'b100 : 3'b011;
        default: y <= 3'b000;
      endcase
    end
  end

  // Output logic
  always @(*) begin
    case (y)
      3'b000: z_out = 1'b0;
      3'b001: z_out = 1'b0;
      3'b010: z_out = 1'b0;
      3'b011: z_out = 1'b1;
      3'b100: z_out = 1'b1;
      default: z_out = 1'b0;
    endcase
  end

  assign z = z_out;

endmodule