module cylinder_lateral_area(input clk, input rst_n, input start, input [31:0] radius, input [31:0] height, output reg [63:0] result, output reg done);
  localparam [31:0] TWO_PI = 32'h06487E;
  reg [31:0] radius_reg;
  reg [31:0] height_reg;
  reg [63:0] stage1;
  reg start_d1, start_d2;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      radius_reg <= 0;
      height_reg <= 0;
      stage1 <= 0;
      start_d1 <= 0;
      start_d2 <= 0;
      result <= 0;
      done <= 0;
    end else begin
      if (start) begin
        radius_reg <= radius;
        height_reg <= height;
      end
      start_d1 <= start;
      start_d2 <= start_d1;
      if (start_d1) stage1 <= TWO_PI * radius_reg;
      if (start_d2) result <= (stage1 * height_reg) >> 32;
      done <= start_d2;
    end
  end
endmodule