module polyline_xfinder(
  input clk,
  input rst_n,
  input start,
  input [23:0] a,
  input [23:0] b,
  output reg [63:0] x,
  output reg valid
);

  typedef enum {IDLE, COMP_K, DIV_X1, DIV_X0, MIN_X, DONE} state_t;
  state_t state, next_state;

  reg [31:0] cycle;
  reg [23:0] a_reg, b_reg;
  reg no_sol;
  reg has_x0;

  // Precomputed values
  reg [24:0] apb, amb;                   // a+b & a-b (25-bit)
  reg [24:0] two_b;                      // 2*b (25-bit)
  reg [7:0] k1, k0;                      // Computed k values (floor)

  // Division registers
  reg [63:0] dividend, divisor;
  reg [63:0] x1_val, x0_val;
  wire [63:0] quotient;
  reg div_start;
  wire div_ready;

  // Fixed-point divider (32-cycle iterative)
  fixed_div_32 div_unit(
    .clk(clk),
    .rst_n(rst_n),
    .start(div_start),
    .dividend(dividend),
    .divisor(divisor),
    .quotient(quotient),
    .ready(div_ready)
  );

  // Main state machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      valid <= 0;
      x <= 0;
      cycle <= 0;
    end else begin
      state <= next_state;
      case (state)
        IDLE: cycle <= 0;
        default: cycle <= cycle + 1;
      endcase

      // Capture results
      if (div_ready && state == DIV_X1) x1_val <= quotient;
      if (div_ready && state == DIV_X0) x0_val <= quotient;

      // Output final results
      if (state == DONE) begin
        valid <= !no_sol;
        x <= (no_sol || !has_x0 || (x1_val < x0_val)) ? x1_val : x0_val;
      end else if (state != DONE) begin
        valid <= 0;
      end
    end
  end

  // Next state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: if (start) next_state = COMP_K;
      COMP_K: begin
        if (no_sol) next_state = DONE;
        else next_state = DIV_X1;
      end
      DIV_X1: if (cycle[5]) next_state = has_x0 ? DIV_X0 : MIN_X; // 32 cycles
      DIV_X0: if (cycle[5]) next_state = MIN_X;     // 32 cycles total
      MIN_X:  next_state = DONE;
      DONE:   next_state = IDLE;
    endcase
  end

  // Precompute values
  always_ff @(posedge clk) begin
    if (state == IDLE && start) begin
      a_reg <= a;
      b_reg <= b;
      apb <= a + b;
      amb <= a - b;
      two_b <= {b, 1'b0};               // 2*b

      // Check initial conditions
      no_sol <= (b > a) || (b == 0);
      has_x0 <= (a >= b) && (b != 0);
    end

    if (state == COMP_K && !no_sol) begin
      // Compute k1 = floor((a+b)/(2*b))
      k1 <= two_b ? (apb / two_b) : 0;
      // Compute k0 (if applicable)
      k0 <= has_x0 ? (amb / two_b) : 0;
      has_x0 <= has_x0 && (k0 > 0);
    end

    // Setup dividers
    if (next_state == DIV_X1) begin
      dividend <= {32'd0, apb} << 32;   // Convert to Q32.32
      divisor  <= {32'd0, 2*k1} << 32;
      div_start <= 1;
    end else if (next_state == DIV_X0) begin
      dividend <= {32'd0, amb} << 32;
      divisor  <= {32'd0, 2*k0} << 32;
      div_start <= 1;
    end else begin
      div_start <= 0;
    end
  end
endmodule

module fixed_div_32(
  input clk,
  input rst_n,
  input start,
  input [63:0] dividend,
  input [63:0] divisor,
  output reg [63:0] quotient,
  output ready
);
  reg [5:0] count;
  reg [63:0] rem, div_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count <= 6'd32;
      quotient <= 0;
      ready <= 0;
    end else if (start) begin
      rem <= dividend;
      div_reg <= divisor;
      count <= 0;
      quotient <= 0;
      ready <= 0;
    end else if (count < 32) begin
      rem <= rem << 1;
      if (rem >= div_reg) begin
        rem <= rem - div_reg;
        quotient <= (quotient << 1) | 1'b1;
      end else begin
        quotient <= quotient << 1;
      end
      count <= count + 1;
      ready <= (count == 31);
    end else begin
      ready <= 0;
    end
  end
endmodule