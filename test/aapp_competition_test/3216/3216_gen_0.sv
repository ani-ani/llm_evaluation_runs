module repeating_decimal_to_fraction(
  input clk,
  input rst_n,
  input start,
  input [9:0] integer_part,
  input [13:0] non_rep_frac,
  input [13:0] rep_frac,
  input [3:0] repeat_count,
  output reg [26:0] numerator,
  output reg [26:0] denominator,
  output reg done
);

  // State encoding
  localparam IDLE       = 3'd0;
  localparam CALC_DENOM = 3'd1;
  localparam CALC_NUM   = 3'd2;
  localparam GCD_CALC   = 3'd3;
  localparam DIVIDE     = 3'd4;
  localparam DONE       = 3'd5;

  reg [2:0] state, next_state;

  // Internal registers
  reg [26:0] int_part_reg;
  reg [26:0] non_rep_reg;
  reg [26:0] rep_reg;
  reg [3:0]  rpt_cnt_reg;

  reg [3:0] total_frac_digits; // fixed 4 digits max (per specification)
  reg [3:0] nv_digits;         // number of non-repeating digits

  reg [26:0] pow10_nv;
  reg [26:0] pow10_nv_rpt;

  reg [26:0] raw_numerator;
  reg [26:0] raw_denominator;

  reg [26:0] gcd_a;
  reg [26:0] gcd_b;
  reg [26:0] gcd_next_a;
  reg [26:0] gcd_next_b;

  reg [26:0] num_div;
  reg [26:0] den_div;

  reg start_d;

  // Power-of-10 lookup table function (1 to 10^8)
  function automatic [26:0] pow10_lut;
    input [3:0] idx;
    begin
      case (idx)
        4'd0: pow10_lut = 27'd1;
        4'd1: pow10_lut = 27'd10;
        4'd2: pow10_lut = 27'd100;
        4'd3: pow10_lut = 27'd1000;
        4'd4: pow10_lut = 27'd10000;
        4'd5: pow10_lut = 27'd100000;
        4'd6: pow10_lut = 27'd1000000;
        4'd7: pow10_lut = 27'd10000000;
        4'd8: pow10_lut = 27'd100000000;
        default: pow10_lut = 27'd0;
      endcase
    end
  endfunction

  // Edge detect for start (optional robustness)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      start_d <= 1'b0;
    else
      start_d <= start;
  end

  wire start_pulse = start & ~start_d;

  // FSM state register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start_pulse)
          next_state = CALC_DENOM;
      end
      CALC_DENOM: begin
        next_state = CALC_NUM;
      end
      CALC_NUM: begin
        next_state = GCD_CALC;
      end
      GCD_CALC: begin
        if (gcd_b == 27'd0)
          next_state = DIVIDE;
      end
      DIVIDE: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) // wait for start deassertion before going idle
          next_state = IDLE;
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential operations
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      int_part_reg   <= 27'd0;
      non_rep_reg    <= 27'd0;
      rep_reg        <= 27'd0;
      rpt_cnt_reg    <= 4'd0;
      total_frac_digits <= 4'd4; // fixed maximum per spec
      nv_digits      <= 4'd0;
      pow10_nv       <= 27'd0;
      pow10_nv_rpt   <= 27'd0;
      raw_numerator  <= 27'd0;
      raw_denominator<= 27'd0;
      gcd_a          <= 27'd0;
      gcd_b          <= 27'd0;
      num_div        <= 27'd0;
      den_div        <= 27'd0;
      numerator      <= 27'd0;
      denominator    <= 27'd0;
      done           <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start_pulse) begin
            // Latch inputs
            int_part_reg <= {17'd0, integer_part};
            non_rep_reg  <= {13'd0, non_rep_frac};
            rep_reg      <= {13'd0, rep_frac};
            rpt_cnt_reg  <= repeat_count;
            // total_frac_digits fixed to max 4; nv = total - repeat_count
            total_frac_digits <= 4'd4;
            nv_digits <= (4'd4 >= repeat_count) ? (4'd4 - repeat_count) : 4'd0;
          end
        end

        CALC_DENOM: begin
          // Compute powers of 10
          pow10_nv     <= pow10_lut(nv_digits);
          pow10_nv_rpt <= pow10_lut(nv_digits + rpt_cnt_reg);
          // denominator = 10^(nv + rpt) - 10^nv
          raw_denominator <= pow10_lut(nv_digits + rpt_cnt_reg) - pow10_lut(nv_digits);
        end

        CALC_NUM: begin
          // Using formula:
          // Numerator = (int*10^(nv+rpt) + non_rep*10^rpt + rep)
          //            - (int*10^nv + non_rep)
          // NOTE: use registered powers from previous state
          // Compute terms
          // A = int * 10^(nv+rpt)
          // B = non_rep * 10^rpt
          // C = rep
          // D = int * 10^nv
          // E = non_rep
          // raw_numerator = (A + B + C) - (D + E)
          // Using pow10_lut for 10^rpt
          reg [26:0] A, B, C, D, E;
          A = int_part_reg * pow10_nv_rpt;
          B = non_rep_reg * pow10_lut(rpt_cnt_reg);
          C = rep_reg;
          D = int_part_reg * pow10_nv;
          E = non_rep_reg;
          raw_numerator <= (A + B + C) - (D + E);
          // Initialize GCD operands
          gcd_a <= ((A + B + C) - (D + E));
          gcd_b <= raw_denominator;
        end

        GCD_CALC: begin
          // Euclidean algorithm: iterative modulo
          if (gcd_b != 27'd0) begin
            // Compute next step
            gcd_next_a = gcd_b;
            gcd_next_b = gcd_a % gcd_b;
            gcd_a <= gcd_next_a;
            gcd_b <= gcd_next_b;
          end
        end

        DIVIDE: begin
          // gcd_a holds GCD when gcd_b == 0
          if (gcd_a != 27'd0) begin
            num_div <= raw_numerator / gcd_a;
            den_div <= raw_denominator / gcd_a;
          end else begin
            num_div <= raw_numerator;
            den_div <= raw_denominator;
          end
        end

        DONE: begin
          numerator   <= num_div;
          denominator <= den_div;
          done        <= 1'b1;
        end

        default: begin
          // no-op
        end
      endcase
    end
  end

endmodule