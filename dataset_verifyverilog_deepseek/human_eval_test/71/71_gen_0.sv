module triangle_area(
  input clk,
  input rst_n,
  input [7:0] a,
  input [7:0] b,
  input [7:0] c,
  input start,
  output reg [15:0] area,
  output reg valid,
  output reg error
);
  
  // Internal registers
  reg [7:0] a_reg, b_reg, c_reg;
  reg triangle_valid;
  reg [8:0] s;
  reg [8:0] s_reg;
  
  reg [8:0] s_minus_a, s_minus_b, s_minus_c;
  reg [17:0] temp1, temp2;
  reg [31:0] area_sq;
  
  // Sqrt pipeline registers
  reg [15:0] x0, x1, x2, x3, x4;
  
  // Control
  reg [3:0] counter;
  wire cnt_start = (start && triangle_valid && counter == 4'd0);

  // Triangle validation (combinational)
  always @(*) begin
    triangle_valid = ( (a_reg + b_reg > c_reg) &&
                    (a_reg + c_reg > b_reg) &&
                    (b_reg + c_reg > a_reg) );
  end

  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      a_reg <= 8'd0;
      b_reg <= 8'd0;
      c_reg <= 8'd0;
      s_reg <= 9'd0;
      s_minus_a <= 9'd0;
      s_minus_b <= 9'd0;
      s_minus_c <= 9'd0;
      temp1 <= 18'd0;
      temp2 <= 18'd0;
      area_sq <= 32'd0;
      x0 <= 16'd0;
      x1 <= 16'd0;
      x2 <= 16'd0;
      x3 <= 16'd0;
      x4 <= 16'd0;
    end else begin
      if(start) begin
        a_reg <= a;
        b_reg <= b;
        c_reg <= c;
        s <= (a + b + c) >> 1; // 9-bit s
        s_reg <= s;
      end
      
      if(cnt_start) begin
        s_minus_a <= s_reg - a_reg;
        s_minus_b <= s_reg - b_reg;
        s_minus_c <= s_reg - c_reg;
      end
      
      if(counter == 4'd1) begin
        temp1 <= s_reg * s_minus_a;
        temp2 <= s_minus_b * s_minus_c;
      end
      
      if(counter == 4'd2) begin
        area_sq <= temp1 * temp2;
        x0 <= (area_sq != 0) ? 16'h8000 : 16'h0000; // Initial sqrt guess
      end
      
      // Sqrt iterations (5 cycles)
      if(counter == 4'd3) x1 <= (x0 + area_sq / x0) >> 1;
      if(counter == 4'd4) x2 <= (x1 + area_sq / x1) >> 1;
      if(counter == 4'd5) x3 <= (x2 + area_sq / x2) >> 1;
      if(counter == 4'd6) x4 <= (x3 + area_sq / x3) >> 1;
    end
  end

  // Counter logic
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      counter <= 4'd0;
    end else begin
      case(counter)
        4'd0: if(start && triangle_valid) counter <= counter + 1;
        4'd8: counter <= 4'd0;
        default: if(counter != 4'd0) counter <= counter + 1;
      endcase
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      valid <= 1'b0;
      error <= 1'b0;
      area <= 16'd0;
    end else begin
      if(start) begin
        if(!triangle_valid) begin
          // Invalid triangle
          valid <= 1'b1;
          error <= 1'b1;
          area <= 16'hFFFF;
        end else begin
          valid <= 1'b0;
          error <= 1'b0;
        end
      end else if(counter == 4'd8) begin
        valid <= 1'b1;
        error <= 1'b0;
        area <= x4[15:0];
      end else begin
        valid <= 1'b0;
        error <= 1'b0;
      end
    end
  end

endmodule