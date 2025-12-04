module smoothie_transport(input clk, input rst_n, input start, input [15:0] d, input [15:0] w, input [15:0] c, output reg [31:0] result, output reg done);

  // Input registers
  reg [15:0] d_reg, w_reg, c_reg;
  reg w_le_c;

  // Division registers
  reg div_start;
  reg [23:0] dividend, divisor, quotient;
  reg [4:0] div_counter;

  // State counter
  reg [4:0] counter;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      d_reg <= 16'd0;
      w_reg <= 16'd0;
      c_reg <= 16'd0;
      w_le_c <= 1'b0;
      div_start <= 1'b0;
      div_counter <= 5'd0;
      quotient <= 24'd0;
      counter <= 5'd16;
      result <= 32'd0;
      done <= 1'b0;
    end else begin
      done <= 1'b0;
      div_start <= 1'b0;

      if (start) begin
        d_reg <= d;
        w_reg <= w;
        c_reg <= c;
        w_le_c <= (w <= c);
        dividend <= w << 8;
        divisor <= c;
        div_start <= 1'b1;
        div_counter <= 5'd0;
        counter <= 5'd0;
      end else if (counter < 16) begin
        counter <= counter + 1;
        
        if (counter == 15) begin
          if (w_le_c) begin
            result <= (w_reg >= d_reg) ? (w_reg - d_reg) << 8 : 32'd0;
          end else begin
            begin : complex_path_calc
              reg [15:0] wc_int;
              reg [31:0] term1, term2, sum_val;
              reg [31:0] base_consumption;
              wc_int = (quotient * c_reg) >> 8;
              
              if (d_reg >= wc_int) begin
                result <= 32'd0;
              end else begin
                term1 = {8'd0, quotient};
                term2 = term1 - (24'd256);
                term2 = term2 << 1;
                sum_val = term1 + term2;
                base_consumption = sum_val * d_reg;
                
                if ((w_reg << 8) >= base_consumption) begin
                  result <= (w_reg << 8) - base_consumption;
                end else begin
                  result <= 32'd0;
                end
              end
            end
          end
          done <= 1'b1;
        end
      end
    end
  end

  always @(posedge clk) begin
    if (!rst_n) begin
      div_counter <= 5'd0;
      quotient <= 24'd0;
    end else if (div_start) begin
      div_counter <= 5'd1;
      quotient <= 24'd0;
    end else if (div_counter < 16) begin
      if (dividend >= (divisor << (23 - div_counter))) begin
        dividend <= dividend - (divisor << (23 - div_counter));
        quotient <= quotient | (24'b1 << (23 - div_counter));
      end
      div_counter <= div_counter + 1;
    end
  end

endmodule