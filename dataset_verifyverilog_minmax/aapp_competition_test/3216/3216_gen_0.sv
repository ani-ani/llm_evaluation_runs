module repeating_decimal_to_fraction (
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
  localparam IDLE        = 4'b0000;
  localparam CALC_DENOM  = 4'b0001;
  localparam CALC_NUM    = 4'b0010;
  localparam GCD_CALC    = 4'b0011;
  localparam DIVIDE      = 4'b0100;
  localparam DONE        = 4'b0101;

  // Function to count number of decimal digits in a 14‑bit value
  function [3:0] count_digits;
    input [13:0] val;
    begin
      if (val == 0)          count_digits = 0;
      else if (val < 10)     count_digits = 1;
      else if (val < 100)    count_digits = 2;
      else if (val < 1000)   count_digits = 3;
      else                   count_digits = 4;
    end
  endfunction

  // 10^k lookup table (k = 0 … 8) – all values fit in 27 bits
  logic [26:0] pow10 [0:8];
  initial begin
    pow10[0] = 27'd1;
    pow10[1] = 27'd10;
    pow10[2] = 27'd100;
    pow10[3] = 27'd1000;
    pow10[4] = 27'd10000;
    pow10[5] = 27'd100000;
    pow10[6] = 27'd1000000;
    pow10[7] = 27'd10000000;
    pow10[8] = 27'd100000000;
  end

  // Internal registers
  logic [3:0] state, next_state;
  logic [3:0] nv;               // number of non‑repeating digits
  logic [3:0] rpt;              // repeat count (same as repeat_count)
  logic [3:0] total_frac_digits;
  logic [26:0] denom;           // internal denominator
  logic [26:0] num;             // internal numerator (27‑bit)
  logic [26:0] gcd_a, gcd_b, gcd_temp;
  logic [5:0]  gcd_iter;        // GCD loop counter (max 50)

  // Combinational next‑state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE:        if (start)              next_state = CALC_DENOM;
      CALC_DENOM:                       next_state = CALC_NUM;
      CALC_NUM:                         next_state = GCD_CALC;
      GCD_CALC:   if (gcd_b == 0 || gcd_iter >= 6'd50) next_state = DIVIDE;
      DIVIDE:                           next_state = DONE;
      DONE:      if (!start)             next_state = IDLE;
      default:                           next_state = IDLE;
    endcase
  end

  // Sequential state machine and register updates
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      numerator  <= 27'd0;
      denominator<= 27'd0;
      done       <= 1'b0;
      nv         <= 4'd0;
      rpt        <= 4'd0;
      total_frac_digits <= 4'd0;
      denom      <= 27'd0;
      num        <= 27'd0;
      gcd_a      <= 27'd0;
      gcd_b      <= 27'd0;
      gcd_temp   <= 27'd0;
      gcd_iter   <= 6'd0;
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          // Clear outputs and internal state
          numerator  <= 27'd0;
          denominator<= 27'd0;
          done       <= 1'b0;
          nv         <= 4'd0;
          rpt        <= 4'd0;
          total_frac_digits <= 4'd0;
          denom      <= 27'd0;
          num        <= 27'd0;
          gcd_a      <= 27'd0;
          gcd_b      <= 27'd0;
          gcd_temp   <= 27'd0;
          gcd_iter   <= 6'd0;
        end

        CALC_DENOM: begin
          // Determine the number of non‑repeating digits
          nv <= count_digits(non_rep_frac);
          rpt <= repeat_count;
          total_frac_digits <= count_digits(non_rep_frac) + repeat_count;
          // Denominator = 10^(total) - 10^(nv)
          denom <= pow10[total_frac_digits] - pow10[nv];
        end

        CALC_NUM: begin
          // Compute the numerator using the formula:
          // (int*10^(nv+rpt) + non_rep*10^rpt + rep) - (int*10^nv + non_rep)
          num <= ( ($unsigned(integer_part) * $unsigned(pow10[total_frac_digits]))
                 + ($unsigned(non_rep_frac) * $unsigned(pow10[rpt]))
                 + $unsigned(rep_frac)
                 - (($unsigned(integer_part) * $unsigned(pow10[nv])) + $unsigned(non_rep_frac)) );
        end

        GCD_CALC: begin
          if (gcd_iter == 0) begin
            // First iteration: initialise GCD registers with numerator and denominator
            gcd_a <= num;
            gcd_b <= denom;
            gcd_iter <= 1;
          end else begin
            // Subsequent iterations: Euclidean algorithm step
            gcd_temp <= gcd_a % gcd_b;
            gcd_a    <= gcd_b;
            gcd_b    <= gcd_temp;
            gcd_iter <= gcd_iter + 1;
          end
        end

        DIVIDE: begin
          // Reduce the fraction by the GCD (stored in gcd_a when gcd_b == 0)
          numerator   <= num / gcd_a;
          denominator <= denom / gcd_a;
          done        <= 1'b1;
        end

        DONE: begin
          // Hold the done flag; return to IDLE when start is deasserted
        end

        default: begin
          // Stay in IDLE
        end
      endcase
    end
  end

endmodule