module pokemon_gcd_counter (
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

  typedef enum logic [1:0] {IDLE, PROCESSING, DONE} state_t;
  state_t state, next_state;
  
  logic [4:0] cycle_count;
  logic [2:0] latched_n;
  logic [7:0] latched_s [0:7];
  logic [7:0] enables;
  
  // Prime ROM (25 primes)
  logic [6:0] primes [0:24] = '{7'd2,7'd3,7'd5,7'd7,7'd11,7'd13,7'd17,7'd19,7'd23,7'd29,7'd31,7'd37,7'd41,7'd43,7'd47,7'd53,7'd59,7'd61,7'd67,7'd71,7'd73,7'd79,7'd83,7'd89,7'd97};
  
  logic [7:0] mod_zero;
  logic [3:0] current_count;
  logic [3:0] max_count_reg;

  // Enable logic
  always_comb begin
    enables = '0;
    for (int i=0; i<8; i++)
      enables[i] = (i < latched_n);
  end
  
  // Parallel modulo checks
  generate for (genvar i=0; i<8; i++) begin : mod_gen
    assign mod_zero[i] = (latched_s[i] % primes[cycle_count] == '0) & enables[i];
  end endgenerate
  
  // Current count sum
  always_comb begin
    current_count = '0;
    for (int i=0; i<8; i++)
      current_count += mod_zero[i];
  end
  
  // State machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
  end
  
  always_comb begin
    next_state = state;
    case (state)
      IDLE:        if (start) next_state = PROCESSING;
      PROCESSING:  if (cycle_count == 24) next_state = DONE;
      DONE:        next_state = IDLE;
      default:     next_state = IDLE;
    endcase
  end
  
  // Cycle counter
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_count <= '0;
    end else begin
      if (state == PROCESSING) cycle_count <= cycle_count + 1;
      else cycle_count <= '0;
    end
  end
  
  // Latch inputs
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      latched_n <= '0;
      foreach (latched_s[i]) latched_s[i] <= '0;
    end else if (state == IDLE && start) begin
      latched_n <= n;
      latched_s[0] <= s0;
      latched_s[1] <= s1;
      latched_s[2] <= s2;
      latched_s[3] <= s3;
      latched_s[4] <= s4;
      latched_s[5] <= s5;
      latched_s[6] <= s6;
      latched_s[7] <= s7;
    end
  end
  
  // Max tracking logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      max_count_reg <= '0;
    end else begin
      if (state == PROCESSING && current_count > max_count_reg)
        max_count_reg <= current_count;
      else if (state == IDLE)
        max_count_reg <= '0;
    end
  end
  
  // Output logic
  assign done = (state == DONE);
  assign max_count = (state == DONE) ? ((max_count_reg == '0) ? 4'd1 : max_count_reg) : '0;
  
endmodule