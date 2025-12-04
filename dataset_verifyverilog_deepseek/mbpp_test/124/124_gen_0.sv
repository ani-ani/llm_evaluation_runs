module complex_angle(input clk, input rst_n, input start, input [31:0] real_part, input [31:0] imag_part, output reg [31:0] angle, output reg done);

  // Internal registers
  reg [31:0] real_reg, imag_reg;
  reg [1:0] quadrant;
  reg [3:0] iter_count;
  reg calculating;
  
  // CORDIC registers
  reg signed [31:0] x, y, z;
  
  // Arctan table in Q16.16 format for atan(2^-i), i=0 to 15
  localparam logic signed [31:0] arctan_table [0:15] = '{
    32'h0000C90F, // i=0
    32'h000076B1, // i=1
    32'h00003EB6, // i=2
    32'h00001FD5, // i=3
    32'h00000FFA, // i=4
    32'h000007FF, // i=5
    32'h000003FF, // i=6
    32'h000001FF, // i=7
    32'h000000FF, // i=8
    32'h0000007F, // i=9
    32'h0000003F, // i=10
    32'h0000001F, // i=11
    32'h0000000F, // i=12
    32'h00000007, // i=13
    32'h00000003, // i=14
    32'h00000001  // i=15
  };
  
  // Pi constant in Q16.16
  localparam logic signed [31:0] pi = 32'h0003243F;
  
  // Quadrant adjustment
  reg signed [31:0] adjusted_angle;
  always_comb begin
    case (quadrant)
      2'b00: adjusted_angle = z; // Quadrant I
      2'b10: adjusted_angle = pi - z; // Quadrant II
      2'b11: adjusted_angle = z - pi; // Quadrant III
      2'b01: adjusted_angle = -z; // Quadrant IV
      default: adjusted_angle = z;
    endcase
  end
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      real_reg <= 0;
      imag_reg <= 0;
      quadrant <= 0;
      calculating <= 0;
      done <= 0;
      iter_count <= 0;
      x <= 0;
      y <= 0;
      z <= 0;
      angle <= 0;
    end else begin
      done <= 0;
      if (calculating) begin
        if (iter_count == 15) begin
          calculating <= 0;
          done <= 1;
          iter_count <= 0;
          angle <= adjusted_angle; // Capture the adjusted angle
        end else begin
          iter_count <= iter_count + 1;
        end
        // CORDIC iteration
        if (y[31]) begin // negative y, rotate in positive direction
          x <= x + (y >>> iter_count);
          y <= y - (x >>> iter_count);
          z <= z + arctan_table[iter_count];
        end else begin // positive y, rotate in negative direction
          x <= x - (y >>> iter_count);
          y <= y + (x >>> iter_count);
          z <= z - arctan_table[iter_count];
        end
      end else if (start) begin
        // Latch inputs and initialize CORDIC
        real_reg <= real_part;
        imag_reg <= imag_part;
        quadrant <= {real_part[31], imag_part[31]};
        x <= real_part[31] ? -real_part : real_part; // absolute value
        y <= imag_part[31] ? -imag_part : imag_part; // absolute value
        z <= 0;
        calculating <= 1;
        iter_count <= 0;
      end
    end
  end

endmodule