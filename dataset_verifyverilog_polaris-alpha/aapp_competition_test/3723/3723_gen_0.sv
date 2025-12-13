module pokemon_gcd_counter(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [2:0]  n,
  input  logic [7:0]  s0,
  input  logic [7:0]  s1,
  input  logic [7:0]  s2,
  input  logic [7:0]  s3,
  input  logic [7:0]  s4,
  input  logic [7:0]  s5,
  input  logic [7:0]  s6,
  input  logic [7:0]  s7,
  output logic [3:0]  max_count,
  output logic        done
);

  typedef enum logic [1:0] {
    IDLE        = 2'b00,
    PROCESSING  = 2'b01,
    DONE_STATE  = 2'b10
  } state_t;

  state_t state, next_state;

  // Prime ROM index: 0..24
  logic [4:0] prime_idx;      // 25 entries
  logic [4:0] prime_idx_next;

  // Latched inputs at start
  logic [2:0]  n_reg;
  logic [7:0]  s_reg [7:0];

  // Current prime
  logic [6:0] current_prime;

  // Count for current prime
  logic [3:0] curr_count;

  // Max count register
  logic [3:0] max_count_reg;
  logic [3:0] max_count_next;

  // Combinational divisibility flags (up to 8, gated by n_reg)
  logic [7:0] div_flags;

  // Done register
  logic done_reg;

  // Prime ROM (combinational)
  function automatic logic [6:0] get_prime(input logic [4:0] idx);
    case (idx)
      5'd0:  get_prime = 7'd2;
      5'd1:  get_prime = 7'd3;
      5'd2:  get_prime = 7'd5;
      5'd3:  get_prime = 7'd7;
      5'd4:  get_prime = 7'd11;
      5'd5:  get_prime = 7'd13;
      5'd6:  get_prime = 7'd17;
      5'd7:  get_prime = 7'd19;
      5'd8:  get_prime = 7'd23;
      5'd9:  get_prime = 7'd29;
      5'd10: get_prime = 7'd31;
      5'd11: get_prime = 7'd37;
      5'd12: get_prime = 7'd41;
      5'd13: get_prime = 7'd43;
      5'd14: get_prime = 7'd47;
      5'd15: get_prime = 7'd53;
      5'd16: get_prime = 7'd59;
      5'd17: get_prime = 7'd61;
      5'd18: get_prime = 7'd67;
      5'd19: get_prime = 7'd71;
      5'd20: get_prime = 7'd73;
      5'd21: get_prime = 7'd79;
      5'd22: get_prime = 7'd83;
      5'd23: get_prime = 7'd89;
      5'd24: get_prime = 7'd97;
      default: get_prime = 7'd0;
    endcase
  endfunction

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      prime_idx    <= 5'd0;
      n_reg        <= 3'd0;
      s_reg[0]     <= 8'd0;
      s_reg[1]     <= 8'd0;
      s_reg[2]     <= 8'd0;
      s_reg[3]     <= 8'd0;
      s_reg[4]     <= 8'd0;
      s_reg[5]     <= 8'd0;
      s_reg[6]     <= 8'd0;
      s_reg[7]     <= 8'd0;
      max_count_reg<= 4'd0;
      done_reg     <= 1'b0;
    end else begin
      state     <= next_state;
      prime_idx <= prime_idx_next;
      max_count_reg <= max_count_next;

      // Latch inputs at start when in IDLE
      if (state == IDLE && start) begin
        n_reg    <= n;
        s_reg[0] <= s0;
        s_reg[1] <= s1;
        s_reg[2] <= s2;
        s_reg[3] <= s3;
        s_reg[4] <= s4;
        s_reg[5] <= s5;
        s_reg[6] <= s6;
        s_reg[7] <= s7;
      end

      // done flag update
      if (next_state == DONE_STATE && state != DONE_STATE)
        done_reg <= 1'b1;
      else if (next_state == IDLE)
        done_reg <= 1'b0;
    end
  end

  // Current prime
  assign current_prime = get_prime(prime_idx);

  // Divisibility checks (8 parallel, gated by n_reg)
  // Only the first n_reg strengths are considered
  always_comb begin
    div_flags = 8'b0;
    if (n_reg > 3'd0) div_flags[0] = (s_reg[0] % current_prime) == 0;
    if (n_reg > 3'd1) div_flags[1] = (s_reg[1] % current_prime) == 0;
    if (n_reg > 3'd2) div_flags[2] = (s_reg[2] % current_prime) == 0;
    if (n_reg > 3'd3) div_flags[3] = (s_reg[3] % current_prime) == 0;
    if (n_reg > 3'd4) div_flags[4] = (s_reg[4] % current_prime) == 0;
    if (n_reg > 3'd5) div_flags[5] = (s_reg[5] % current_prime) == 0;
    if (n_reg > 3'd6) div_flags[6] = (s_reg[6] % current_prime) == 0;
    if (n_reg > 3'd7) div_flags[7] = (s_reg[7] % current_prime) == 0;
  end

  // Count number of divisible strengths for current prime
  always_comb begin
    curr_count = 4'd0;
    curr_count = curr_count + (div_flags[0] ? 4'd1 : 4'd0);
    curr_count = curr_count + (div_flags[1] ? 4'd1 : 4'd0);
    curr_count = curr_count + (div_flags[2] ? 4'd1 : 4'd0);
    curr_count = curr_count + (div_flags[3] ? 4'd1 : 4'd0);
    curr_count = curr_count + (div_flags[4] ? 4'd1 : 4'd0);
    curr_count = curr_count + (div_flags[5] ? 4'd1 : 4'd0);
    curr_count = curr_count + (div_flags[6] ? 4'd1 : 4'd0);
    curr_count = curr_count + (div_flags[7] ? 4'd1 : 4'd0);
  end

  // FSM next-state logic and max_count update
  always_comb begin
    next_state      = state;
    prime_idx_next  = prime_idx;
    max_count_next  = max_count_reg;

    case (state)
      IDLE: begin
        prime_idx_next = 5'd0;
        max_count_next = 4'd0;
        if (start) begin
          next_state = PROCESSING;
        end
      end

      PROCESSING: begin
        // Update max_count for current prime
        if (curr_count > max_count_reg)
          max_count_next = curr_count;

        // After processing prime_idx 24, move to DONE_STATE
        if (prime_idx == 5'd24) begin
          next_state     = DONE_STATE;
          prime_idx_next = prime_idx; // hold
        end else begin
          prime_idx_next = prime_idx + 5'd1;
        end
      end

      DONE_STATE: begin
        // Stay DONE until start deasserted and reasserted; prevent new starts while high
        if (!start) begin
          next_state     = IDLE;
          prime_idx_next = 5'd0;
        end
      end

      default: begin
        next_state      = IDLE;
        prime_idx_next  = 5'd0;
        max_count_next  = 4'd0;
      end
    endcase
  end

  // Apply special case at output: if max_count is zero, output 1
  assign max_count = (max_count_reg == 4'd0) ? 4'd1 : max_count_reg;
  assign done      = done_reg;

endmodule