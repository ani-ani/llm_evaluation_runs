module compare_numbers (
  input clk,
  input rst_n,
  input start,
  input [79:0] a_str, // 40-bit ASCII string
  input [79:0] b_str, // 40-bit ASCII string
  input [1:0] a_type,
  input [1:0] b_type,
  output reg [79:0] result_str,
  output reg [1:0] result_type,
  output reg done,
  output reg none
);

  // Internal signals and state machine
  localparam S0 = 3'b000;
  localparam S1 = 3'b001;
  localparam S2 = 3'b010;
  localparam S3 = 3'b011;
  localparam S4 = 3'b100;
  
  reg [2:0] state, next_state;
  reg start_r;
  wire start_pulse;
  
  reg [15:0] a_fixed, b_fixed;
  reg [15:0] a_fixed_r, b_fixed_r;
  reg a_is_num_r, b_is_num_r;
  reg eq_r, a_lt_b_r, b_lt_a_r;
  reg [1:0] a_type_r, b_type_r;
  reg [79:0] a_str_r, b_str_r;
  
  // Character classification
  function is_digit(input [7:0] c);
    is_digit = (c >= "0" && c <= "9");
  endfunction
  
  function is_sign_or_digit(input [7:0] c);
    is_sign_or_digit = (c == "-" || (c >= "0" && c <= "9"));
  endfunction
  
  function is_valid_numeric(input [7:0] c);
    is_valid_numeric = (c == "-" || c == "." || c == "," || (c >= "0" && c <= "9") || c == 8'h20 /* space */);
  endfunction
  
  // Trim leading/trailing spaces (indices 0..39)
  function [5:0] trim_spaces(input [79:0] s);
    integer i, j_start, j_end;
    begin
      j_start = 0;
      for (i = 0; i < 40; i = i + 1) begin
        if (s[i*8 +: 8] != 8'h20) begin
          j_start = i;
          i = 40; // break
        end
      end
      j_end = 39;
      for (i = 39; i >= 0; i = i - 1) begin
        if (s[i*8 +: 8] != 8'h20) begin
          j_end = i;
          i = -1; // break
        end
      end
      if (j_start <= j_end) begin
        trim_spaces = (j_end - j_start + 1);
      end else begin
        trim_spaces = 6'd0;
      end
    end
  endfunction
  
  // Parse a numeric (int/float) ASCII string into Q8.8 fixed-point (16-bit, two's complement)
  function [15:0] str_to_q8_8(input [79:0] s);
    integer i, j_start, j_end, len;
    reg [7:0] c;
    reg [7:0] int_part [0:7]; // up to 8 chars for safety (we only need up to 3)
    reg [7:0] frac_part [0:7]; // up to 2 chars + null
    reg [3:0] int_len, frac_len, digits_int, digits_frac;
    reg sign;
    reg valid, have_dot, have_comma;
    reg invalid_char;
    reg [15:0] int_val;
    reg [7:0] frac_raw;
    reg [8:0] frac_rounded;
    reg [15:0] res;
    
    begin
      // Defaults
      sign = 1'b0;
      valid = 1'b1;
      have_dot = 1'b0;
      have_comma = 1'b0;
      int_len = 4'd0;
      frac_len = 4'd0;
      digits_int = 4'd0;
      digits_frac = 4'd0;
      invalid_char = 1'b0;
      for (i = 0; i < 8; i = i + 1) begin
        int_part[i] = 8'h00;
        if (i < 7) frac_part[i] = 8'h00;
        else frac_part[7] = 8'h00;
      end
      
      // Trim and find bounds
      len = trim_spaces(s);
      j_start = 0;
      for (i = 0; i < 40; i = i + 1) begin
        if (s[i*8 +: 8] != 8'h20) begin j_start = i; i = 40; end
      end
      j_end = j_start + len - 1;
      
      if (len == 0) begin
        valid = 1'b0; // treat as invalid -> zero
      end
      
      // Handle optional leading sign
      c = s[j_start*8 +: 8];
      if (valid && (c == "-")) begin
        sign = 1'b1;
        j_start = j_start + 1;
        if (j_start > j_end) begin
          valid = 1'b0; // only a sign is invalid
        end
      end
      
      // Scan rest for characters to validate and build tokens
      for (i = j_start; i <= j_end && valid; i = i + 1) begin
        c = s[i*8 +: 8];
        if (c == "." || c == ",") begin
          if (have_dot || have_comma) begin
            valid = 1'b0; // multiple decimal separators
          end else begin
            have_dot = (c == ".");
            have_comma = (c == ",");
          end
        end else if (is_digit(c)) begin
          if (!have_dot && !have_comma) begin
            if (digits_int < 4'd3) begin // only up to 3 integer digits matter
              int_part[digits_int] = c;
              digits_int = digits_int + 1;
              int_len = int_len + 1;
            end else begin
              // extra integer digits ignored (range will clamp anyway)
            end
          end else begin
            if (digits_frac < 4'd2) begin
              frac_part[digits_frac] = c;
              digits_frac = digits_frac + 1;
              frac_len = frac_len + 1;
            end else begin
              // extra fractional digits ignored
            end
          end
        end else if (c == 8'h20) begin
          // spaces allowed anywhere in trimmed region
        end else begin
          // any other char is invalid for numeric input
          valid = 1'b0;
        end
      end
      
      if (!valid) begin
        res = 16'h0000;
      end else begin
        // Convert integer part
        int_val = 16'h0000;
        for (i = 0; i < int_len; i = i + 1) begin
          int_val = int_val * 10 + (int_part[i] - "0");
        end
        
        // Convert fractional part (up to 2 digits)
        // frac_raw is the two-digit fractional part as an integer (00..99)
        frac_raw = 8'd0;
        for (i = 0; i < frac_len; i = i + 1) begin
          frac_raw = frac_raw * 10 + (frac_part[i] - "0");
        end
        
        // Round to 8 fractional bits: (frac_raw * 256 + 50) / 100
        // But since frac_len <= 2, we handle that as:
        // if frac_len == 2: (frac_raw * 256 + 50) / 100
        // if frac_len == 1: (frac_raw * 256 + 5) / 10  (or reuse formula with 50 and 100 is also ok)
        if (frac_len == 2) begin
          frac_rounded = {1'b0, frac_raw, 8'b00000000} + 9'd50; // frac_raw << 8
          // divide by 100
          case (frac_rounded)
            9'd0,9'd1,9'd2,9'd3,9'd4,9'd5,9'd6,9'd7,9'd8,9'd9,
            9'd10,9'd11,9'd12,9'd13,9'd14,9'd15,9'd16,9'd17,9'd18,9'd19,
            9'd20,9'd21,9'd22,9'd23,9'd24,9'd25,9'd26,9'd27,9'd28,9'd29,
            9'd30,9'd31,9'd32,9'd33,9'd34,9'd35,9'd36,9'd37,9'd38,9'd39,
            9'd40,9'd41,9'd42,9'd43,9'd44,9'd45,9'd46,9'd47,9'd48,9'd49:
              frac_rounded = 9'd0;
            default:
              frac_rounded = frac_rounded / 8'd100;
          endcase
        end else if (frac_len == 1) begin
          // multiply by 25.6 -> use 2560 as scale: (frac_raw * 2560 + 50) / 100
          frac_rounded = {1'b0, frac_raw, 10'b0000000000} + 9'd50; // frac_raw << 10
          case (frac_rounded)
            9'd0,9'd1,9'd2,9'd3,9'd4,9'd5,9'd6,9'd7,9'd8,9'd9,
            9'd10,9'd11,9'd12,9'd13,9'd14,9'd15,9'd16,9'd17,9'd18,9'd19,
            9'd20,9'd21,9'd22,9'd23,9'd24,9'd25,9'd26,9'd27,9'd28,9'd29,
            9'd30,9'd31,9'd32,9'd33,9'd34,9'd35,9'd36,9'd37,9'd38,9'd39,
            9'd40,9'd41,9'd42,9'd43,9'd44,9'd45,9'd46,9'd47,9'd48,9'd49:
              frac_rounded = 9'd0;
            default:
              frac_rounded = frac_rounded / 8'd100;
          endcase
        end else begin
          frac_rounded = 9'd0;
        end
        
        if (sign) res = -(int_val) - {8'h00, frac_rounded[7:0]};
        else      res =  (int_val) + {8'h00, frac_rounded[7:0]};
      end
      
      str_to_q8_8 = res;
    end
  endfunction
  
  // Determine if trimmed string is purely sign/digits/punct (no letters, etc.)
  function is_numeric_str(input [79:0] s);
    integer i, j_start, j_end, len;
    reg [7:0] c;
    begin
      is_numeric_str = 1'b0;
      len = trim_spaces(s);
      if (len == 0) begin
        is_numeric_str = 1'b0;
        return;
      end
      j_start = 0;
      for (i = 0; i < 40; i = i + 1) begin
        if (s[i*8 +: 8] != 8'h20) begin j_start = i; i = 40; end
      end
      j_end = j_start + len - 1;
      
      is_numeric_str = 1'b1;
      for (i = j_start; i <= j_end; i = i + 1) begin
        c = s[i*8 +: 8];
        if (!is_valid_numeric(c)) begin
          is_numeric_str = 1'b0;
          i = j_end; // break
        end
      end
    end
  endfunction
  
  // Convert numeric Q8.8 fixed-point back to original-style ASCII (up to 3 int, 2 frac)
  function [79:0] q8_8_to_str(input [15:0] q);
    reg [15:0] value;
    reg sign;
    reg [6:0] int_abs; // 0..127
    reg [7:0] frac_xx; // 0..255
    reg [7:0] digit_bytes [0:10]; // temp buffer
    integer i, k, idx, dpos;
    reg [7:0] ch;
    reg [79:0] out_s;
    begin
      out_s = 80'h00;
      if (q == 16'h0000) begin
        // "0.00" by default for numeric zero
        out_s[7:0] = "0";  out_s[15:8] = "."; out_s[23:16] = "0"; out_s[31:24] = "0";
        q8_8_to_str = out_s;
        return;
      end
      
      sign = q[15];
      value = sign ? (-q) : q;
      int_abs = value[15:8];
      frac_xx = value[7:0];
      
      // Fractional two digits: round to nearest
      // (frac * 100 + 128) / 256  is equivalent to (frac*25 + 8) / 64
      // Simpler: (frac * 100 + 128) / 256
      k = (frac_xx * 100 + 128) / 256; // 0..99
      
      // Build characters in reverse into digit_bytes[10..0]
      idx = 0;
      if (k == 0) begin
        digit_bytes[idx] = "0"; idx = idx + 1;
        digit_bytes[idx] = "0"; idx = idx + 1;
      end else begin
        digit_bytes[idx] = 8'( (k % 10) + "0" ); idx = idx + 1;
        digit_bytes[idx] = 8'( ((k/10) % 10) + "0" ); idx = idx + 1;
      end
      digit_bytes[idx] = "."; idx = idx + 1;
      
      if (int_abs == 0) begin
        digit_bytes[idx] = "0"; idx = idx + 1;
      end else begin
        for (i = 0; i < 3 && idx < 11; i = i + 1) begin
          dpos = (int_abs % 10);
          digit_bytes[idx] = 8'(dpos + "0");
          idx = idx + 1;
          int_abs = int_abs / 10;
        end
      end
      
      if (sign) begin
        digit_bytes[idx] = "-"; idx = idx + 1;
      end
      
      // Write back in reverse order to out_s
      for (i = 0; i < idx; i = i + 1) begin
        ch = digit_bytes[idx - 1 - i];
        out_s[i*8 +: 8] = ch;
      end
      q8_8_to_str = out_s;
    end
  endfunction
  
  // Start pulse (one clk)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) start_r <= 1'b0;
    else        start_r <= start;
  end
  assign start_pulse = start && (!start_r);
  
  // State transition
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= S0;
    else        state <= next_state;
  end
  
  // FSM combinatorial logic
  always @(*) begin
    next_state = S0;
    case (state)
      S0: next_state = start_pulse ? S1 : S0;
      S1: next_state = S2;
      S2: next_state = S3;
      S3: next_state = S4;
      S4: next_state = S0; // done outputs registered in S4
      default: next_state = S0;
    endcase
  end
  
  // Pipeline: latch inputs in S1
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a_type_r <= 2'b00;
      b_type_r <= 2'b00;
      a_str_r <= 80'h00;
      b_str_r <= 80'h00;
    end else if (next_state == S1) begin
      a_type_r <= a_type;
      b_type_r <= b_type;
      a_str_r <= a_str;
      b_str_r <= b_str;
    end
  end
  
  // S2: Convert numeric strings to Q8.8 and flag string-like content
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a_fixed_r <= 16'h0000;
      b_fixed_r <= 16'h0000;
      a_is_num_r <= 1'b0;
      b_is_num_r <= 1'b0;
    end else if (next_state == S2) begin
      // Treat invalid numeric inputs as zero as required
      a_fixed_r <= str_to_q8_8(a_str_r);
      b_fixed_r <= str_to_q8_8(b_str_r);
      a_is_num_r <= is_numeric_str(a_str_r);
      b_is_num_r <= is_numeric_str(b_str_r);
    end
  end
  
  // S3: Compare fixed-point values
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a_fixed <= 16'h0000;
      b_fixed <= 16'h0000;
      eq_r <= 1'b0;
      a_lt_b_r <= 1'b0;
      b_lt_a_r <= 1'b0;
    end else if (next_state == S3) begin
      a_fixed <= a_fixed_r;
      b_fixed <= b_fixed_r;
      eq_r    <= (a_fixed_r == b_fixed_r);
      a_lt_b_r <= (a_fixed_r < b_fixed_r);
      b_lt_a_r <= (a_fixed_r > b_fixed_r);
    end
  end
  
  // S4: Decide outputs and register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result_str <= 80'h00;
      result_type <= 2'b00;
      none <= 1'b0;
      done <= 1'b0;
    end else if (next_state == S4) begin
      done <= 1'b1;
      // none is asserted when values are equal (based on S3 results)
      none <= (eq_r || (!a_lt_b_r && !b_lt_a_r));
      
      // Default: result cleared on equality (as per spec)
      result_str <= 80'h00;
      result_type <= 2'b00;
      
      if (!eq_r) begin
        if (b_lt_a_r) begin
          // A is larger
          if (a_type_r == 2'b10) begin
            result_str <= a_str_r; // return original ASCII string
            result_type <= 2'b10;
          end else begin
            // return reconstructed numeric style string from Q8.8
            result_str <= q8_8_to_str(a_fixed);
            result_type <= a_type_r;
          end
        end else if (a_lt_b_r) begin
          // B is larger
          if (b_type_r == 2'b10) begin
            result_str <= b_str_r;
            result_type <= 2'b10;
          end else begin
            result_str <= q8_8_to_str(b_fixed);
            result_type <= b_type_r;
          end
        end else begin
          // Equal case handled above (none asserted, result cleared)
          result_str <= 80'h00;
          result_type <= 2'b00;
        end
      end else begin
        // Equal case
        result_str <= 80'h00;
        result_type <= 2'b00;
      end
    end else begin
      done <= 1'b0;
      // hold last result; nothing else changes outside S4
    end
  end
  
endmodule