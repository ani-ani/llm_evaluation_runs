module palindrome_parts (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [15:0][7:0] s,
  output reg [3:0] k,
  output [15:0][7:0] parts,
  output reg done
);

  typedef enum logic [2:0] { IDLE, COUNT, CALC_K, BUILD, DONE } state_t;
  reg [2:0] state, next_state;
  reg [5:0] freq [256];
  reg [3:0] odd_count;
  reg [3:0] count_idx;
  reg [3:0] k_reg;
  reg [15:0][7:0] parts_reg;
  reg [6:0] timer;

  // FSM State Transition
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
  end

  // Next State Logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE:   if (start) next_state = COUNT;
      COUNT:  if (count_idx == n) next_state = CALC_K;
      CALC_K: next_state = BUILD;
      BUILD:  if (timer == 7'd99) next_state = DONE;
      DONE:   next_state = IDLE;
    endcase
  end

  // Timer
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) timer <= 0;
    else if (start) timer <= 0;
    else if (state != IDLE) timer <= timer + 1;
  end

  // Frequency Counting
  integer f;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count_idx <= 0;
      for (f=0; f<256; f++) freq[f] <= 0;
    end else if (state == IDLE && start) begin
      count_idx <= 0;
      for (f=0; f<256; f++) freq[f] <= 0;
    end else if (state == COUNT) begin
      freq[s[count_idx]] <= freq[s[count_idx]] + 1;
      count_idx <= count_idx + 1;
    end
  end

  // Calculate odd_count
  integer c;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) odd_count <= 0;
    else if (state == COUNT && count_idx == n) begin
      odd_count <= 0;
      for (c=0; c<256; c++)
        if (freq[c] > 0 && freq[c][0]) odd_count <= odd_count + 1;
    end
  end

  // Calculate k
  logic [3:0] found_k;
  logic found;
  always_comb begin
    found = 0;
    found_k = 16;
    for (int i=odd_count; i<=16; i++) begin
      if (n % i == 0) begin
        if (odd_count > 0) begin
          if ((n / i) % 2) begin
            found = 1;
            found_k = i;
            break;
          end
        end else begin
          found = 1;
          found_k = i;
          break;
        end
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) k_reg <= 0;
    else if (state == CALC_K) k_reg <= found ? found_k : 16;
  end

  // Build palindromes (simplified placeholder)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) parts_reg <= '0;
    else if (state == BUILD) begin
      for (int p=0; p<16; p++) parts_reg[p] <= p < n ? s[p] : 0;
    end
  end

  // Output assignments
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) done <= 0;
    else done <= (state == DONE);
  end

  assign parts = parts_reg;
  always_ff @(posedge clk) begin
    if (state == CALC_K) k <= k_reg;
  end
endmodule