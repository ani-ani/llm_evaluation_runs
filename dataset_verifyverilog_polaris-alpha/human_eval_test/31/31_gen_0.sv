module is_prime (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [15:0] n,
  output logic        ready,
  output logic        is_prime
);

  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    CHECK = 2'b01
  } state_t;

  state_t       state, next_state;
  logic [15:0]  n_reg;
  logic [15:0]  divisor;
  logic [31:0]  divisor_sq;
  logic         found_divisor;
  logic         is_prime_next;
  logic         ready_next;

  // Combinational: divisor squared
  assign divisor_sq = divisor * divisor;

  // Sequential state and registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      n_reg       <= 16'd0;
      divisor     <= 16'd0;
      is_prime    <= 1'b0;
      ready       <= 1'b0;
    end else begin
      state    <= next_state;
      is_prime <= is_prime_next;
      ready    <= ready_next;
      if (state == IDLE && start) begin
        n_reg   <= n;
        divisor <= 16'd2;
      end else if (state == CHECK && !found_divisor && (divisor_sq <= n_reg)) begin
        divisor <= divisor + 16'd1;
      end
    end
  end

  // Combinational next-state and outputs
  always_comb begin
    next_state     = state;
    is_prime_next  = is_prime;
    ready_next     = 1'b0;
    found_divisor  = 1'b0;

    case (state)
      IDLE: begin
        // Default outputs in IDLE
        is_prime_next = is_prime;
        if (start) begin
          // Handle simple/early cases using n directly
          if (n < 16'd2) begin
            // Not prime, result available immediately next cycle
            is_prime_next = 1'b0;
            ready_next    = 1'b1;
            next_state    = IDLE;
          end else if (n == 16'd2) begin
            // 2 is prime
            is_prime_next = 1'b1;
            ready_next    = 1'b1;
            next_state    = IDLE;
          end else begin
            // For n > 2, move to CHECK; n_reg and divisor captured in seq block
            is_prime_next = 1'b1; // assume prime until divisor found
            next_state    = CHECK;
          end
        end
      end

      CHECK: begin
        // Default keep previous assumption and stay until done
        is_prime_next = is_prime;
        // Check for divisor if within sqrt(n_reg)
        if (divisor_sq <= n_reg) begin
          if ((n_reg % divisor) == 16'd0) begin
            // Found divisor
            found_divisor  = 1'b1;
            is_prime_next  = 1'b0;
            ready_next     = 1'b1;
            next_state     = IDLE;
          end
        end else begin
          // No divisor up to sqrt(n_reg)
          ready_next = 1'b1;
          next_state = IDLE;
        end
      end

      default: begin
        next_state    = IDLE;
        is_prime_next = 1'b0;
        ready_next    = 1'b0;
      end
    endcase
  end

endmodule