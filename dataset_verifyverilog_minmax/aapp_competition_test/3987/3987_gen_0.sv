module dragon_subsequence(
  input clk, // clock signal
  input rst_n, // active-low reset (async)
  input start, // pulse high for 1 cycle to start computation
  input [7:0] seq, // 8-bit input where each bit represents value (0=1, 1=2)
  output reg [3:0] max_length, // maximum subsequence length (4 bits)
  output reg done // high when computation complete
);

  // State registers (4-bit each)
  reg [3:0] state_a; // current max for type 1-only
  reg [3:0] state_b; // current max for type1->type2
  reg [3:0] state_c; // current max for type1->type2->type1
  reg [3:0] state_d; // current max for type1->type2->type1->type2

  // Step counter (0..7) and shift register to process one element per cycle
  reg [2:0] step_cnt;
  reg [7:0] shift_reg;

  // Internal signals for next state logic
  wire [3:0] next_state_a, next_state_b, next_state_c, next_state_d;
  wire is_one;
  wire [3:0] new_a_1, new_c_1, new_b_2, new_d_2;
  wire is_step7;

  // Current element (0 -> 1, 1 -> 2)
  assign is_one = shift_reg[0];

  // Increments (using add-without-overflow approximation since max is 8)
  assign new_a_1 = state_a + 1; // 1-only path
  assign new_c_1 = (state_b > state_c ? state_b : state_c) + 1; // extend from type2->type1 or continue in type1
  assign new_b_2 = (state_a > state_b ? state_a : state_b) + 1; // extend from type1-only or continue in type1->type2
  assign new_d_2 = state_c + 1; // extend from type1->type2->type1

  // Next state computations
  assign next_state_a = is_one ? new_a_1 : state_a;
  assign next_state_b = is_one ? state_b : new_b_2;
  assign next_state_c = is_one ? new_c_1 : state_c;
  assign next_state_d = is_one ? state_d : new_d_2;

  // Detect the last step (8 elements processed)
  assign is_step7 = (step_cnt == 3'b111);

  // FSM: Idle (done=1, keep result) and Running (process 8 cycles)
  reg running;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      running <= 1'b0;
      done <= 1'b0;
    end else if (start) begin
      running <= 1'b1;
      done <= 1'b0;
    end else if (is_step7) begin
      running <= 1'b0;
      done <= 1'b1;
    end
    // else hold current values
  end

  // Shift register and step counter
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      shift_reg <= 8'b0;
      step_cnt <= 3'b0;
    end else if (start) begin
      shift_reg <= seq;
      step_cnt <= 3'b0;
    end else if (running) begin
      shift_reg <= {1'b0, shift_reg[7:1]};
      step_cnt <= step_cnt + 1;
    end
  end

  // State updates per cycle during running
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_a <= 4'b0;
      state_b <= 4'b0;
      state_c <= 4'b0;
      state_d <= 4'b0;
    end else if (start) begin
      // Initialize states on the first element before the first shift
      if (is_one) begin
        state_a <= 4'b1; // first '1' counted in state_a
        state_c <= 4'b0; // need a preceding '2' to grow this, so start at 0
      end else begin
        state_a <= 4'b0;
        state_c <= 4'b0;
      end
      state_b <= 4'b0;
      state_d <= 4'b0;
    end else if (running) begin
      state_a <= next_state_a;
      state_b <= next_state_b;
      state_c <= next_state_c;
      state_d <= next_state_d;
    end
  end

  // Result capture and hold
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      max_length <= 4'b0;
    end else if (start) begin
      max_length <= 4'b0; // clear until computed
    end else if (is_step7) begin
      // Combine final states to get overall max length
      max_length <= (state_a > state_b ? state_a : state_b);
      max_length <= (state_c > max_length ? state_c : max_length);
      max_length <= (state_d > max_length ? state_d : max_length);
    end
    // else hold current max_length
  end

endmodule