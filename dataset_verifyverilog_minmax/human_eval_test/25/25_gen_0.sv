module prime_factorization (
  input  clk,
  input  rst_n,
  input  start,
  input  [15:0] n_in,
  output reg [7:0] factors [0:15],
  output reg [3:0] factor_count,
  output reg valid
);

  // State machine states
  typedef enum logic [1:0] { IDLE = 2'b00, DIVIDE = 2'b01, INCREMENT = 2'b10, DONE = 2'b11 } state_t;
  state_t state, next_state;

  // Computation variables
  reg [16:0] remainder, next_remainder;  // up to 65535 (17 bits for safety)
  reg [15:0] divisor, next_divisor;      // up to 65535
  reg [3:0]  next_count;
  reg [7:0]  next_factors [0:15];

  // Start pulse (one-shot)
  reg start_d, start_pulse;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d <= 1'b0;
    end else begin
      start_d <= start;
    end
  end
  assign start_pulse = start && !start_d;

  // Sequential state update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      remainder <= 17'h0;
      divisor   <= 16'h0;
      factor_count <= 4'h0;
      valid <= 1'b0;
      // Zero factors array
      for (int i = 0; i < 16; i++) factors[i] <= 8'h0;
    end else begin
      state        <= next_state;
      remainder    <= next_remainder;
      divisor      <= next_divisor;
      factor_count <= next_count;
      valid        <= (next_state == DONE);
      for (int i = 0; i < 16; i++) factors[i] <= next_factors[i];
    end
  end

  // Combinational next-state logic
  always_comb begin
    next_state = state;
    next_remainder = remainder;
    next_divisor = divisor;
    next_count = factor_count;
    for (int i = 0; i < 16; i++) next_factors[i] = factors[i];

    case (state)
      IDLE: begin
        next_divisor = 16'd2;
        next_remainder = n_in;
        next_count = 4'd0;
        for (int i = 0; i < 16; i++) next_factors[i] = 8'h0;
        if (start_pulse) begin
          next_state = DIVIDE;
        end
      end

      DIVIDE: begin
        next_remainder = remainder;
        next_divisor = divisor;
        next_count = factor_count;
        for (int i = 0; i < 16; i++) next_factors[i] = factors[i];

        if (remainder == 17'd1) begin
          next_state = DONE;
        end else if ((remainder % divisor) == 17'd0) begin
          // Factor found: store and divide
          next_factors[factor_count] = divisor[7:0];
          next_count = factor_count + 1;
          next_remainder = remainder / divisor;
          // stay in DIVIDE to test same divisor (handles powers of a prime)
        end else begin
          // Not divisible, move to next divisor
          next_state = INCREMENT;
        end
      end

      INCREMENT: begin
        next_divisor = divisor + 1;
        next_remainder = remainder;
        next_count = factor_count;
        for (int i = 0; i < 16; i++) next_factors[i] = factors[i];
        next_state = DIVIDE;
      end

      DONE: begin
        // Hold outputs until next start pulse
        next_state = IDLE;
        next_remainder = remainder;
        next_divisor = divisor;
        next_count = factor_count;
        for (int i = 0; i < 16; i++) next_factors[i] = factors[i];
      end

      default: next_state = IDLE;
    endcase
  end

endmodule