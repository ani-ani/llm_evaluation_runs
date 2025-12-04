module rgb_to_hsv (
  input clk,
  input rst_n,
  input start,
  input [7:0] r,
  input [7:0] g,
  input [7:0] b,
  output reg [15:0] h,
  output reg [15:0] s,
  output reg [15:0] v,
  output reg done
);

  reg [3:0] cycle;
  reg processing;
  reg [9:0] r_scaled, g_scaled, b_scaled;
  reg [9:0] r_reg, g_reg, b_reg;
  reg [9:0] max_val, min_val, delta;
  reg [20:0] hue_base;
  reg [27:0] sat_dividend;
  reg [9:0] sat_divisor;
  reg [17:0] val_dividend;
  reg [18:0] val_divisor;
  reg [27:0] sat_quotient, sat_remainder;
  reg [17:0] val_quotient, val_remainder;
  reg sat_start, val_start;
  reg sat_done, val_done;
  reg all_zero;
  reg max_equals_min;
  reg [1:0] max_pos;

  localparam [3:0] DIV_CYCLES = 10;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle <= 0;
      processing <= 0;
      done <= 0;
      h <= 0;
      s <= 0;
      v <= 0;
      sat_start <= 0;
      val_start <= 0;
    end else begin
      done <= 0;
      
      // Normalization ROM - cycle 1
      if (processing && cycle == 1) begin
        r_scaled <= (r_reg * 16'd1000) / 8'd255;
        g_scaled <= (g_reg * 16'd1000) / 8'd255;
        b_scaled <= (b_reg * 16'd1000) / 8'd255;
      end
      
      // Find max/min values - cycle 2
      if (processing && cycle == 2) begin
        if (r_scaled >= g_scaled && r_scaled >= b_scaled) begin
          max_val <= r_scaled;
          max_pos <= 2'b00;
        end else if (g_scaled >= b_scaled) begin
          max_val <= g_scaled;
          max_pos <= 2'b01;
        end else begin
          max_val <= b_scaled;
          max_pos <= 2'b10;
        end
        
        if (r_scaled <= g_scaled && r_scaled <= b_scaled) begin
          min_val <= r_scaled;
        end else if (g_scaled <= b_scaled) begin
          min_val <= g_scaled;
        end else begin
          min_val <= b_scaled;
        end
      end
      
      // Calculate delta + special cases - cycle 3
      if (processing && cycle == 3) begin
        delta <= max_val - min_val;
        max_equals_min <= (max_val == min_val);
        all_zero <= (max_val == 0);
      end
      
      // Hue base calculation - cycle 4
      if (processing && cycle == 4) begin
        case (max_pos)
          2'b00: hue_base <= (g_scaled - b_scaled) * 18'd60;
          2'b01: hue_base <= (b_scaled - r_scaled) * 18'd60 + 18'd12000;
          2'b10: hue_base <= (r_scaled - g_scaled) * 18'd60 + 18'd24000;
        endcase
      end
      
      // Hue correction - cycle 5
      if (processing && cycle == 5) begin
        if (max_equals_min) begin
          h <= 0;
        end else begin
          if (hue_base[20]) 
            h <= (hue_base + 36000) % 36000;
          else
            h <= hue_base < 36000 ? hue_base[15:0] : hue_base - 16'd36000;
        end
      end
      
      // Setup sat/val divisions - cycle 4
      if (processing && cycle == 4) begin
        sat_dividend <= delta * 20'd100000;
        val_dividend <= max_val * 18'd100000;
        sat_divisor <= max_val;
        val_divisor <= 300000;
        sat_start <= ~all_zero;
        val_start <= 1'b1;
        
        if (all_zero) begin
          sat_quotient <= 0;
          val_quotient <= 0;
          sat_done <= 1;
          val_done <= 1;
        end else begin
          sat_done <= 0;
          val_done <= 0;
        end
      end
      
      // Saturation division
      if (processing && sat_start && !sat_done) begin
        if (cycle < 4 + DIV_CYCLES) begin
          if (sat_dividend >= {sat_divisor, 18'b0}) begin
            sat_quotient <= sat_quotient | (1 << (4 + DIV_CYCLES - cycle -1));
            sat_dividend <= sat_dividend - {sat_divisor, 18'b0};
          end
          sat_dividend <= sat_dividend << 1;
        end else if (cycle == 4 + DIV_CYCLES) begin
          sat_done <= 1;
          sat_quotient <= sat_quotient | (sat_dividend[27:18] >= sat_divisor);
        end
      end
      
      // Value division
      if (processing && val_start && !val_done) begin
        if (cycle < 4 + DIV_CYCLES) begin
          if (val_dividend >= val_divisor) begin
            val_quotient <= val_quotient + 1;
            val_dividend <= val_dividend - val_divisor;
          end
          val_dividend <= val_dividend << 1;
        end else if (cycle == 4 + DIV_CYCLES) begin
          val_done <= 1;
          if (val_dividend >= val_divisor)
            val_quotient <= val_quotient + 1;
        end
      end
      
      // Final saturation/value adjustment - cycle 15
      if (processing && cycle == 15) begin
        s <= all_zero ? 0 : (sat_quotient / 10);
        v <= val_quotient / 30;
        done <= 1;
      end
      
      // Start handling
      if (start) begin
        cycle <= 1;
        processing <= 1;
        r_reg <= r;
        g_reg <= g;
        b_reg <= b;
      end else if (processing) begin
        if (cycle < 15) begin
          cycle <= cycle + 1;
        end else begin
          cycle <= 0;
          processing <= 0;
        end
      end
    end
  end
endmodule