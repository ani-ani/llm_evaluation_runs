module harmonic_sum (
  input  clk,
  input  rst_n,
  input  start,
  input  [3:0] n_in,
  output reg [15:0] sum,
  output reg done
);

  // Q8.8 fixed-point lookup table for 1/k (k = 1..15)
  // Each entry is (1/k)*256 rounded to nearest integer.
  // 1/1=256 (0x0100), 1/2=128 (0x0080), 1/3~=85 (0x0055), 1/4=64 (0x0040),
  // 1/5=51 (0x0033), 1/6~=43 (0x002B), 1/7~=37 (0x0025), 1/8=32 (0x0020),
  // 1/9~=28 (0x001C), 1/10=26 (0x001A), 1/11~=23 (0x0017), 1/12~=21 (0x0015),
  // 1/13~=20 (0x0014), 1/14~=18 (0x0012), 1/15~=17 (0x0011)
  logic [15:0] reciprocal [0:15];
  initial begin
    reciprocal[0] = 16'h0000; // unused
    reciprocal[1] = 16'h0100; // 1.000000
    reciprocal[2] = 16'h0080; // 0.500000
    reciprocal[3] = 16'h0055; // 0.333333
    reciprocal[4] = 16'h0040; // 0.250000
    reciprocal[5] = 16'h0033; // 0.200000
    reciprocal[6] = 16'h002B; // 0.166667
    reciprocal[7] = 16'h0025; // 0.142857
    reciprocal[8] = 16'h0020; // 0.125000
    reciprocal[9] = 16'h001C; // 0.111111
    reciprocal[10] = 16'h001A; // 0.100000
    reciprocal[11] = 16'h0017; // 0.090909
    reciprocal[12] = 16'h0015; // 0.083333
    reciprocal[13] = 16'h0014; // 0.076923
    reciprocal[14] = 16'h0012; // 0.071428
    reciprocal[15] = 16'h0011; // 0.066667
  end

  // Iterative FSM states
  typedef enum logic [1:0] { IDLE = 2'b00, RUN = 2'b01, DONE = 2'b10 } state_t;
  state_t state, next_state;

  reg [3:0] k_reg, k_next;        // current k in 1..(n-1)
  reg [3:0] n_clamped, n_latched; // clamped input n (min 2), latched on start

  // Sequential logic: reset, state, counter, and sum
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= IDLE;
      sum     <= 16'h0;
      done    <= 1'b0;
      k_reg   <= 4'b0;
      n_latched <= 4'b0;
    end else begin
      state   <= next_state;
      k_reg   <= k_next;
      sum     <= sum; // assigned in the combinational block below
      done    <= (next_state == DONE);
      if (state == IDLE && start) begin
        n_latched <= n_clamped;
      end
    end
  end

  // Combinational next-state logic and iterative update
  always_comb begin
    // Default values
    next_state = state;
    k_next     = k_reg;

    unique case (state)
      IDLE: begin
        if (start) begin
          // Start accumulating: k runs from 1 to n_latched-1
          k_next     = 4'd1;
          next_state = RUN;
        end
      end

      RUN: begin
        // Accumulate one term per clock: sum += 1/k_reg
        sum = sum + reciprocal[k_reg];

        if (k_reg >= (n_latched - 1)) begin
          next_state = DONE;
          k_next     = 4'd0;
        end else begin
          k_next = k_reg + 1;
        end
      end

      DONE: begin
        // Hold result until next start or reset
        if (start) begin
          k_next     = 4'd1;
          next_state = RUN;
        end else begin
          k_next = 4'd0;
        end
      end

      default: next_state = IDLE;
    endcase
  end

  // Clamp n_in to minimum 2 as required
  always_comb begin
    n_clamped = (n_in < 4'd2) ? 4'd2 : n_in;
  end

endmodule
