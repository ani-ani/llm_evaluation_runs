module sector_area(
  input [15:0] radius,
  input [8:0] angle,
  output reg [31:0] area_q,
  output reg invalid
);
  localparam [31:0] PI = 32'h3243F;
  localparam [31:0] INV_360 = 32'h000000B6;
  
  always @(*) begin
    reg [31:0] radius_sq;
    reg [63:0] step1;
    reg [31:0] step2;
    reg [40:0] step3;
    reg [72:0] step4;
    
    invalid = (angle > 9'd360);
    
    if (invalid) begin
      area_q = 32'hFFFFFFFF;
    end else begin
      radius_sq = radius * radius;
      step1 = PI * radius_sq;
      step2 = step1[47:16];
      step3 = step2 * angle;
      step4 = step3 * INV_360;
      area_q = step4[47:16];
    end
  end
endmodule