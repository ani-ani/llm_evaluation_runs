module bit_count_sorter(
  input clk,
  input rst_n,
  input start,               // pulse to begin sorting
  input signed [7:0] data_in [0:7],
  output reg signed [7:0] sorted_data [0:7],
  output reg done            // high when sort complete (within 64 cycles)
);

  // Internal storage (using unpacked arrays of bit vectors for counting/ordering)
  logic [7:0] work [0:7];    // current working array being sorted
  logic [7:0] work_next [0:7];
  logic [2:0] i_reg, i_next; // outer loop index (0..7)
  logic [2:0] j_reg, j_next; // inner loop index (0..6)

  // Cycle counter to enforce <= 64 comparison cycles
  logic [6:0] cycle_cnt_reg, cycle_cnt_next;
  logic sort_enable;

  // Edge detector for start pulse (synchronous to clk)
  logic start_shft [1:0];
  logic start_rising;

  // State machine
  typedef enum logic {IDLE = 1'b0, SORT = 1'b1} state_t;
  state_t state, next_state;

  // Update sequential elements
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int k = 0; k < 8; ++k) begin
        work[k] <= 8'h0;
        sorted_data[k] <= 8'sh0;
      end
      i_reg <= 3'b0;
      j_reg <= 3'b0;
      cycle_cnt_reg <= 7'b0;
      start_shft[0] <= 1'b0;
      start_shft[1] <= 1'b0;
      state <= IDLE;
      done <= 1'b0;
    end else begin
      // Shift register to detect start rising edge
      start_shft[0] <= start;
      start_shft[1] <= start_shft[0];
      start_rising <= start_shft[0] & ~start_shft[1];

      // Capture state and counters
      work <= work_next;
      i_reg <= i_next;
      j_reg <= j_next;
      cycle_cnt_reg <= cycle_cnt_next;
      state <= next_state;
      done <= (next_state == IDLE);  // done is high in IDLE; low during SORT
    end
  end

  // Combinational next-state logic and FSM
  always_comb begin
    // Defaults
    next_state = state;
    work_next = work;
    i_next = i_reg;
    j_next = j_reg;
    cycle_cnt_next = cycle_cnt_reg;
    sort_enable = 1'b0;

    case (state)
      IDLE: begin
        // Start pulse: capture input, initialize indices and counters
        if (start_rising) begin
          for (int k = 0; k < 8; ++k) begin
            work_next[k] = data_in[k];
          end
          i_next = 3'b0;
          j_next = 3'b0;
          cycle_cnt_next = 7'b0;
          next_state = SORT;
        end else begin
          // Keep outputs stable during IDLE (hold sorted_data from last sort)
          work_next = work;
        end
      end

      SORT: begin
        sort_enable = 1'b1;
        work_next = work;

        // Compare-and-swap in a single cycle at (i, j)
        automatic logic [7:0] a = work[i_reg];
        automatic logic [7:0] b = work[j_reg];
        automatic int pop_a = $countones(a);
        automatic int pop_b = $countones(b);

        if ((pop_a > pop_b) || ((pop_a == pop_b) && (a > b))) begin
          // Swap
          work_next[i_reg] = b;
          work_next[j_reg] = a;
        end else begin
          work_next[i_reg] = a;
          work_next[j_reg] = b;
        end

        // Update indices
        if (j_reg < 6) begin
          j_next = j_reg + 1;
          i_next = i_reg;
        end else begin
          j_next = 3'b0;
          if (i_reg < 7) begin
            i_next = i_reg + 1;
          end else begin
            i_next = 3'b0;  // completed
          end
        end

        // Count one comparison per cycle
        cycle_cnt_next = cycle_cnt_reg + 1;

        // Finish if (i,j) loop finished OR 64 cycles reached
        if ((i_reg == 7) && (j_reg == 6) || (cycle_cnt_reg == 6'd63)) begin
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

  // Commit sorted data to outputs when done (i.e., back in IDLE)
  // If rst_n just deasserted, sorted_data already zeroed by reset.
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int k = 0; k < 8; ++k) begin
        sorted_data[k] <= 8'sh0;
      end
      done <= 1'b0;
    end else if (state == SORT && next_state == IDLE) begin
      // One cycle after finishing, present the sorted data
      for (int k = 0; k < 8; ++k) begin
        sorted_data[k] <= $signed(work_next[k]);
      end
      done <= 1'b1;
    end else if (state == IDLE) begin
      done <= 1'b1;
      // During IDLE, keep sorted_data stable; no change required
    end
  end

endmodule
