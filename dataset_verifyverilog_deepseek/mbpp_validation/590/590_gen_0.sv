module polar_to_rect (
  input clk,
  input rst_n,
  input start,
  input [31:0] r_q16,
  input [31:0] theta_q16,
  output reg [31:0] x_q16,
  output reg [31:0] y_q16,
  output reg done
);

  // Internal registers
  reg [31:0] r_reg;
  reg [31:0] theta_reg;
  reg [9:0] lut_index;
  reg [31:0] cos_val;
  reg [31:0] sin_val;
  reg [63:0] product_x;
  reg [63:0] product_y;
  
  // Pipeline shift register
  reg [2:0] pipeline;
  
  // LUT declarations
  reg [31:0] cos_lut [0:1023];
  reg [31:0] sin_lut [0:1023];
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      x_q16 <= '0;
      y_q16 <= '0;
      done <= '0;
      pipeline <= '0;
    end else begin
      done <= '0;
      pipeline <= {pipeline[1:0], 1'b0};
      
      if (start) begin
        r_reg <= r_q16;
        theta_reg <= theta_q16;
        lut_index <= (theta_q16 * 32'd1024) / 32'h28BE5;
        pipeline[0] <= 1'b1;
      end
      
      if (pipeline[0]) begin
        cos_val <= cos_lut[lut_index];
        sin_val <= sin_lut[lut_index];
      end
      
      if (pipeline[1]) begin
        product_x <= r_reg * cos_val;
        product_y <= r_reg * sin_val;
      end
      
      if (pipeline[2]) begin
        x_q16 <= product_x[47:16];
        y_q16 <= product_y[47:16];
        done <= 1'b1;
      end
    end
  end

endmodule