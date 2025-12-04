module babylonian_sqrt (
  input clk,
  input rst_n,
  input start,
  input [31:0] num,  // Q16.16
  output reg [15:0] result, // Q8.8
  output reg done
);

  // Internal state and datapath
  localparam W = 32;
  localparam S = 16; // fractional bits for Q16.16
  localparam ST_IDLE = 2'b00;
  localparam ST_COMPUTE = 2'b01;
  localparam ST_DONE = 2'b10;

  reg [1:0] state, state_next;
  reg [3:0] iter, iter_next;     // 0..9
  reg [31:0] x, x_next;          // Q16.16
  reg [31:0] n, n_next;          // Q16.16
  reg [31:0] result_reg, result_next;

  // Mul/Div results
  wire [31:0] q;   // Q16.16
  wire [31:0] r;   // remainder, 32-bit signed
  wire div_by_zero;
  wire [31:0] n_div_x; // (num/x) in Q16.16

  // 32-bit signed Baugh-Wooley multiplier (no X states)
  function [63:0] mul_32x32_baugh_wooley (input [31:0] a, input [31:0] b);
    integer i;
    reg [63:0] pp [31:0];
    reg [63:0] sum;
    reg ai, bj;
  begin
    // Generate partial products (two's complement aware)
    for (i = 0; i < 32; i = i + 1) begin
      ai = a[i];
      bj = b[0];
      // Baugh-Wooley: for last column, invert bits
      if (i == 31)
        pp[i] = { {(32){ai & ~bj}}, {ai & bj} };
      else
        pp[i] = { {(32){1'b0}}, {ai & bj} };
    end
    // Accumulate with shifts
    sum = 64'b0;
    for (i = 0; i < 32; i = i + 1) begin
      if (i == 31) begin
        // Invert the last partial product's high word
        pp[i][63:32] = ~pp[i][63:32];
        pp[i][63:32] = pp[i][63:32] + 1'b1;
      end
      sum = sum + (pp[i] << i);
    end
    // Final correction for two's complement
    sum = sum + (({64{a[31]}} & (~b)) | ({64{b[31]}} & (~a))) + 1'b1;
    mul_32x32_baugh_wooley = sum;
  end
  endfunction

  // (a*b) >> S using high 32 bits of Baugh-Wooley product
  function [31:0] mul_hi_s (input [31:0] a, input [31:0] b, input [5:0] s);
    reg [63:0] p;
  begin
    p = mul_32x32_baugh_wooley(a, b);
    mul_hi_s = p[63:32] >> s;
  end
  endfunction

  // Signed division: dividend/divisor -> Q16.16 quotient, 32-bit signed remainder
  // divisor is 32-bit signed; internally we perform 48-bit non-restoring division.
  function [31:0] div_32s_quot (input [31:0] a, input [31:0] b, input [31:0] rem_out);
    reg sign;
    reg [31:0] aa, bb;
    reg [47:0] pr;   // partial remainder (48 bits, 1 sign + 47 magnitude)
    reg [15:0] q;    // 16-bit fractional accumulator
    reg i;
    reg [47:0] bb_shifted;
    reg [1:0] pr_msb;
    reg [31:0] r_temp;
  begin
    sign = a[31] ^ b[31];
    aa = a[31] ? -a : a;
    bb = b[31] ? -b : b;

    pr = {1'b0, aa, 15'b0};  // align 16 fractional bits
    q = 16'b0;
    bb_shifted = {1'b0, bb, 15'b0};

    for (i = 0; i < 16; i = i + 1) begin
      pr = pr << 1;
      pr_msb = pr[47:46];
      if (pr_msb == 2'b00) begin
        pr = pr - bb_shifted;
      end else begin
        pr = pr + bb_shifted;
      end
      if (pr[47] == 1'b0) q[i] = 1'b1; else q[i] = 1'b0;
    end

    // Final correction if remainder is negative
    r_temp = pr[46:15];
    if (pr[47] == 1'b1) begin
      r_temp = r_temp + bb;
      q = q - 1;
    end

    rem_out = (a[31] ? -r_temp : r_temp);
    div_32s_quot = sign ? -q : q;
  end
  endfunction

  // Instantiate combinatorial-like functional units (pure combinational)
  // Because Verilog functions can't have output ports, we pass operands and
  // capture the remainder and quotient through helper wires.
  wire [31:0] rem_wire;
  assign rem_wire = 32'b0; // placeholder; actual remainder is produced within div_32s_quot
  wire [31:0] n_div_x_calc;
  assign n_div_x_calc = div_32s_quot(n, x, r); // r is wired below; we use function for purity

  // Since we need remainder explicitly as a wire too, synthesize it using the function.
  function [31:0] div_32s_rem (input [31:0] a, input [31:0] b, input [31:0] quot_out);
    reg sign;
    reg [31:0] aa, bb;
    reg [47:0] pr;   // partial remainder (48 bits, 1 sign + 47 magnitude)
    reg [15:0] q;    // 16-bit fractional accumulator
    reg i;
    reg [47:0] bb_shifted;
    reg [1:0] pr_msb;
    reg [31:0] r_temp;
  begin
    sign = a[31] ^ b[31];
    aa = a[31] ? -a : a;
    bb = b[31] ? -b : b;

    pr = {1'b0, aa, 15'b0};  // align 16 fractional bits
    q = 16'b0;
    bb_shifted = {1'b0, bb, 15'b0};

    for (i = 0; i < 16; i = i + 1) begin
      pr = pr << 1;
      pr_msb = pr[47:46];
      if (pr_msb == 2'b00) begin
        pr = pr - bb_shifted;
      end else begin
        pr = pr + bb_shifted;
      end
      if (pr[47] == 1'b0) q[i] = 1'b1; else q[i] = 1'b0;
    end

    // Final correction if remainder is negative
    r_temp = pr[46:15];
    if (pr[47] == 1'b1) begin
      r_temp = r_temp + bb;
      q = q - 1;
    end

    div_32s_rem = (a[31] ? -r_temp : r_temp);
    div_32s_quot = sign ? -q : q;
  end
  endfunction

  // We need a final combinational wrapper that exposes both q and r.
  // To avoid complexity, we re-implement it here once for clarity:
  function [31:0] div_32s_both (input [31:0] a, input [31:0] b, output [31:0] rem_out);
    reg sign;
    reg [31:0] aa, bb;
    reg [47:0] pr;   // partial remainder (48 bits, 1 sign + 47 magnitude)
    reg [15:0] q;    // 16-bit fractional accumulator
    reg i;
    reg [47:0] bb_shifted;
    reg [1:0] pr_msb;
    reg [31:0] r_temp;
  begin
    sign = a[31] ^ b[31];
    aa = a[31] ? -a : a;
    bb = b[31] ? -b : b;

    pr = {1'b0, aa, 15'b0};  // align 16 fractional bits
    q = 16'b0;
    bb_shifted = {1'b0, bb, 15'b0};

    for (i = 0; i < 16; i = i + 1) begin
      pr = pr << 1;
      pr_msb = pr[47:46];
      if (pr_msb == 2'b00) begin
        pr = pr - bb_shifted;
      end else begin
        pr = pr + bb_shifted;
      end
      if (pr[47] == 1'b0) q[i] = 1'b1; else q[i] = 1'b0;
    end

    // Final correction if remainder is negative
    r_temp = pr[46:15];
    if (pr[47] == 1'b1) begin
      r_temp = r_temp + bb;
      q = q - 1;
    end

    div_32s_both = sign ? -q : q;
    rem_out = (a[31] ? -r_temp : r_temp);
  end
  endfunction

  // Actually compute quotient and remainder together
  wire [31:0] q_computed, r_computed;
  assign {q_computed, r_computed} = div_32s_both(n, x, 32'b0);
  assign n_div_x = q_computed;
  assign r = r_computed;
  assign div_by_zero = (x == 32'b0);

  // Compute next state combinatorially
  always @(*) begin
    // Defaults
    state_next = state;
    iter_next = iter;
    x_next = x;
    n_next = n;
    result_next = result_reg;
    done = 1'b0;

    case (state)
      ST_IDLE: begin
        if (start) begin
          n_next = num;
          if (num == 32'b0) begin
            result_next = 16'b0;
            done = 1'b1;
            state_next = ST_IDLE; // single-cycle done for zero case
          end else begin
            // g0 = num / 2  (Q16.16)
            x_next = {num[31], num[30:1]}; // arithmetic right shift by 1
            iter_next = 4'b0;
            state_next = ST_COMPUTE;
          end
        end
      end

      ST_COMPUTE: begin
        // Compute one Babylonian iteration per cycle
        if (div_by_zero) begin
          // Defensive: avoid division by zero
          result_next = result_reg; // unchanged
          x_next = x;
        end else begin
          // n_div_x = n / x   (Q16.16)
          // mid = (x >> 1) + (n_div_x >> 1)
          wire [31:0] mid;
          assign mid = ({x[31], x[30:1]} + {n_div_x[31], n_div_x[30:1]});

          // Sum that averages to 0.5 * (x + n/x) with maintained Q16.16
          wire [31:0] x_new;
          // (x + n/x) >> 1 in Q16.16: (x >> 1) + (n_div_x >> 1) already computed in 'mid'
          assign x_new = mid;
          x_next = x_new;

          // Check last iteration (after 9 previous increments, iter==9 means 10th cycle)
          if (iter == 4'd9) begin
            // final result: Q8.8 = Q16.16 >> 8
            result_next = x_new[31:8];
            done = 1'b1;
            state_next = ST_DONE;
          end else begin
            iter_next = iter + 1;
            state_next = ST_COMPUTE;
          end
        end
      end

      ST_DONE: begin
        done = 1'b1; // hold done for one cycle
        result_next = result_reg;
        state_next = ST_IDLE;
      end

      default: state_next = ST_IDLE;
    endcase
  end

  // Sequential update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= ST_IDLE;
      iter <= 4'b0;
      x <= 32'b0;
      n <= 32'b0;
      result_reg <= 16'b0;
      result <= 16'b0;
      done <= 1'b0;
    end else begin
      state <= state_next;
      iter <= iter_next;
      x <= x_next;
      n <= n_next;
      result_reg <= result_next;
      result <= result_next; // update output when done asserted
      done <= done;
    end
  end

endmodule