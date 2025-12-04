module prime_palindrome_compare (
  input clk,
  input rst_n,
  input [15:0] p,
  input [15:0] q,
  input start,
  output reg [9:0] result,
  output reg done
);
  parameter MAX_N = 1000;
  localparam IDLE = 2'b00;
  localparam FILL = 2'b01; // Sieve of Eratosthenes fill
  localparam RUN  = 2'b10; // Iterate n=1..1000
  localparam DONE = 2'b11;

  // One-bit wide BRAM-like storage for prime flags [0..1000]
  // Index 0..MAX_N inclusive (1001 entries) for 1-bit wide inference
  logic [MAX_N:0] prime_mem;
  logic [9:0] n_reg, n_next;
  logic [9:0] pi_reg, pi_next;   // prime count up to current n
  logic [9:0] rub_reg, rub_next; // palindrome count up to current n
  logic [1:0] state, next_state;
  logic [9:0] i_fill;            // sieve iteration index
  logic [9:0] j_fill;            // sieve inner loop index
  logic run_once, run_once_next;

  // Prime test helper (used for the two initial 1s in FILL)
  function bit is_prime(input [9:0] x);
    if (x < 2) return 1'b0;
    for (int k = 2; k * k <= x; k++) begin
      if (x % k == 0) return 1'b0;
    end
    return 1'b1;
  endfunction

  // Palindrome test helper (decimal)
  function bit is_palindrome(input [9:0] x);
    logic [9:0] orig, rev, d;
    orig = x;
    rev = 10'b0;
    d = x;
    while (d > 0) begin
      rev = (rev * 10) + (d % 10);
      d = d / 10;
    end
    return (orig == rev);
  endfunction

  // State and storage updates
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= IDLE;
      run_once <= 1'b0;
      n_reg    <= 10'b0;
      pi_reg   <= 10'b0;
      rub_reg  <= 10'b0;
      i_fill   <= 10'b0;
      j_fill   <= 10'b0;
      prime_mem <= {1'b0, {MAX_N{1'b1}}}; // mem[0]=0, mem[1..MAX_N]=1
      result   <= 10'b0;
      done     <= 1'b0;
    end else begin
      state    <= next_state;
      run_once <= run_once_next;
      n_reg    <= n_next;
      pi_reg   <= pi_next;
      rub_reg  <= rub_next;
      i_fill   <= (next_state == FILL) ? i_fill + 1 : 10'b0;
      j_fill   <= (next_state == FILL) ? j_fill + 1 : 10'b0;
      prime_mem <= prime_mem; // hold
      result   <= result;
      done     <= done;

      // FILL: Sieve of Eratosthenes
      if (next_state == FILL) begin
        if (i_fill == 10'd0) begin
          prime_mem[0] <= 1'b0;
          prime_mem[1] <= is_prime(10'd1);
        end else if (i_fill == 10'd1) begin
          prime_mem[1] <= is_prime(10'd1);
        end else if (i_fill < MAX_N) begin
          if (prime_mem[i_fill]) begin
            for (int j = i_fill * i_fill; j <= MAX_N; j = j + i_fill) begin
              prime_mem[j] <= 1'b0;
            end
          end
        end
      end

      // RUN: Evaluate condition and update result
      if (next_state == RUN) begin
        logic is_p, is_r, ge;
        logic [31:0] lhs, rhs;
        is_p = prime_mem[n_next];
        is_r = is_palindrome(n_next);
        pi_next = pi_reg + (is_p ? 1 : 0);
        rub_next = rub_reg + (is_r ? 1 : 0);
        lhs = (pi_reg + (is_p ? 1 : 0)) * q;
        rhs = (rub_reg + (is_r ? 1 : 0)) * p;
        ge  = (lhs <= rhs);
        if (ge) result <= n_next;
      end else begin
        pi_next  = pi_reg;
        rub_next = rub_reg;
      end

      // DONE: Pulse done for 1 cycle
      if (next_state == DONE) done <= 1'b1;
      else if (state != DONE) done <= 1'b0;
    end
  end

  // Combinational next-state logic
  always_comb begin
    next_state = state;
    run_once_next = run_once;
    n_next = n_reg;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = FILL;
          run_once_next = 1'b1;
        end
      end

      FILL: begin
        if (i_fill >= MAX_N) begin
          next_state = RUN;
          n_next = 10'd1;
        end
      end

      RUN: begin
        if (n_next < MAX_N) begin
          n_next = n_reg + 1;
        end else begin
          next_state = DONE;
        end
      end

      DONE: begin
        next_state = IDLE;
        run_once_next = 1'b0;
      end

      default: next_state = IDLE;
    endcase
  end
endmodule