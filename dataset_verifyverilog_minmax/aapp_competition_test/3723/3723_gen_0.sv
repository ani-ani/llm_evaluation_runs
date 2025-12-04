// SystemVerilog module: pokemon_gcd_counter
// Computes the maximum number of Pokemon Bash can take without fighting.
// - Tracks, for each of 25 primes, how many of the first 'n' strengths are divisible by that prime.
// - Outputs the maximum count across primes. Latency: exactly 25 cycles after start.
module pokemon_gcd_counter (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [7:0] s0, s1, s2, s3, s4, s5, s6, s7,
  output logic [3:0] max_count,
  output logic done
);

  // State machine
  typedef enum logic [1:0] { IDLE = 2'b00, PROCESSING = 2'b01, DONE = 2'b10 } state_t;
  state_t state, next_state;

  // Edge detection for start in IDLE state
  logic start_d;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) start_d <= 1'b0;
    else        start_d <= start;
  end
  wire start_pos = start && !start_d;

  // Capture input strengths and n on start in IDLE
  logic [2:0] n_reg;
  logic [7:0] s_reg [8];
  logic [7:0] valid_s; // bit i indicates s_reg[i] is valid per n
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      n_reg <= 3'd0;
      for (int i = 0; i < 8; i++) s_reg[i] <= 8'd0;
      valid_s <= 8'd0;
    end else if (state == IDLE && start_pos) begin
      n_reg <= n;
      s_reg[0] <= s0;
      s_reg[1] <= s1;
      s_reg[2] <= s2;
      s_reg[3] <= s3;
      s_reg[4] <= s4;
      s_reg[5] <= s5;
      s_reg[6] <= s6;
      s_reg[7] <= s7;
      // Build validity mask for first n entries (n in 1..8)
      valid_s[0] = (n >= 1);
      valid_s[1] = (n >= 2);
      valid_s[2] = (n >= 3);
      valid_s[3] = (n >= 4);
      valid_s[4] = (n >= 5);
      valid_s[5] = (n >= 6);
      valid_s[6] = (n >= 7);
      valid_s[7] = (n >= 8);
    end
  end

  // Prime ROM (first 25 primes up to 100)
  const logic [6:0] PRIMES [25] = '{
    7'd2,  7'd3,  7'd5,  7'd7, 7'd11, 7'd13, 7'd17, 7'd19,
    7'd23, 7'd29, 7'd31, 7'd37, 7'd41, 7'd43, 7'd47, 7'd53,
    7'd59, 7'd61, 7'd67, 7'd71, 7'd73, 7'd79, 7'd83, 7'd89, 7'd97
  };

  // Per-cycle prime index counter
  logic [4:0] prime_idx; // 0..24
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) prime_idx <= 5'd0;
    else if (state == IDLE) prime_idx <= 5'd0;
    else if (state == PROCESSING) prime_idx <= prime_idx + 1'b1;
  end

  // Max counter across primes (1..8, or 1 if all are 1 -> max becomes 1 per spec)
  logic [3:0] max_count_next;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) max_count <= 4'd0;
    else if (state == IDLE) max_count <= 4'd1; // default safe value
    else if (state == PROCESSING) max_count <= max_count_next;
    else if (state == DONE) max_count <= (max_count == 0) ? 4'd1 : max_count;
  end

  // Count how many of the first n strengths are divisible by current prime
  logic [3:0] count;
  logic [3:0] count_next;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) count <= 4'd0;
    else if (state == IDLE) count <= 4'd0;
    else count <= count_next;
  end

  // Compute per-cycle update: count and max_count
  always_comb begin
    count_next = 4'd0;
    if (state == PROCESSING) begin
      logic [3:0] c;
      c = 4'd0;
      for (int i = 0; i < 8; i++) begin
        if (valid_s[i] && (s_reg[i] % PRIMES[prime_idx] == 0))
          c = c + 1'b1;
      end
      count_next = c;
      max_count_next = (c > max_count) ? c : max_count;
    end else begin
      max_count_next = max_count;
    end
  end

  // done pulse during DONE state
  logic done_next;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) done <= 1'b0;
    else done <= done_next;
  end

  // State machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else        state <= next_state;
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE:       next_state = start_pos ? PROCESSING : IDLE;
      PROCESSING: next_state = (prime_idx == 5'd24) ? DONE : PROCESSING;
      DONE:       next_state = IDLE;
      default:    next_state = IDLE;
    endcase
  end

  // done generation
  assign done_next = (state == DONE);

endmodule
