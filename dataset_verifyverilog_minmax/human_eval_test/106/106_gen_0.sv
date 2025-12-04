module factorial_or_sum_list (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  output logic [7:0][15:0] result_array,
  output logic done
);

  typedef enum logic [2:0] {IDLE, INIT, COMPUTE_EVEN, COMPUTE_ODD, STORE, DONE} state_t;
  state_t state, next_state;

  logic [3:0] idx;         // Index of element to compute (0..7)
  logic [3:0] idx_next;
  logic [7:0] mul_cycle;   // 0..7, counts multiplication cycles
  logic [7:0] mul_cycle_next;
  logic [15:0] fact_acc;   // Accumulator for factorial during multi-cycle multiply
  logic [15:0] fact_acc_next;
  logic start_d;

  // Edge detect on start (pulse-based)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d <= 1'b0;
    end else begin
      start_d <= start;
    end
  end
  wire start_pulse = start && !start_d;

  // State register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Output and control registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      idx <= 4'd0;
      mul_cycle <= 8'd0;
      fact_acc <= 16'd1;
    end else begin
      idx <= idx_next;
      mul_cycle <= mul_cycle_next;
      fact_acc <= fact_acc_next;
    end
  end

  // Result array and done are updated by next_state logic
  always_comb begin
    // Defaults (maintain current value)
    result_array = result_array;
    done = done;
    idx_next = idx;
    mul_cycle_next = mul_cycle;
    fact_acc_next = fact_acc;
    next_state = state;

    case (state)
      IDLE: begin
        done = 1'b0;
        result_array = '0;     // Reset outputs
        if (start_pulse) begin
          next_state = INIT;
        end
      end

      INIT: begin
        done = 1'b0;
        result_array = '0;
        idx_next = 4'd0;
        mul_cycle_next = 8'd0;
        fact_acc_next = 16'd1;
        next_state = COMPUTE_EVEN; // Will be corrected in compute block based on (idx+1)
      end

      default: begin
        // fall through
      end
    endcase

    // Determine next state based on (idx+1) parity
    if (state == INIT) begin
      if ((idx + 4'd1) % 2 == 0) next_state = COMPUTE_EVEN;
      else next_state = COMPUTE_ODD;
    end
  end

  // Main compute logic
  always_comb begin
    // Defaults
    idx_next = idx;
    mul_cycle_next = mul_cycle;
    fact_acc_next = fact_acc;
    result_array = result_array;  // maintain current array
    done = done;

    case (state)
      COMPUTE_EVEN: begin
        // i = idx+1 is even, compute factorial i!
        // i ranges from 2,4,6,8 (1..3 multiply cycles)
        if (idx == 4'd0) begin
          // First even i: i=2, 1 multiply (2*1)
          mul_cycle_next = 8'd0;
          fact_acc_next = 16'd1;
        end
        // Multiply on every cycle (including the first one in this state)
        if (mul_cycle == 8'd0) begin
          // First multiply: fact_acc = i * 1
          fact_acc_next = (idx + 4'd1) * 16'd1;
          mul_cycle_next = mul_cycle + 8'd1;
        end else begin
          // Subsequent multiplies: fact_acc = (k+1) * fact_acc
          // Current factor = mul_cycle + 1
          fact_acc_next = (mul_cycle + 8'd1) * fact_acc;
          mul_cycle_next = mul_cycle + 8'd1;
        end

        if ((idx + 4'd1) == 4'd2) begin
          // i=2 -> 1 multiply cycle
          if (mul_cycle_next == 8'd1) next_state = STORE;
        end else if ((idx + 4'd1) == 4'd4) begin
          // i=4 -> 3 multiply cycles
          if (mul_cycle_next == 8'd3) next_state = STORE;
        end else if ((idx + 4'd1) == 4'd6) begin
          // i=6 -> 5 multiply cycles
          if (mul_cycle_next == 8'd5) next_state = STORE;
        end else if ((idx + 4'd1) == 4'd8) begin
          // i=8 -> 7 multiply cycles
          if (mul_cycle_next == 8'd7) next_state = STORE;
        end else begin
          // Should never reach here because i is even only for 2,4,6,8
          next_state = STORE;
        end
      end

      COMPUTE_ODD: begin
        // i = idx+1 is odd, compute sum(1..i) = i*(i+1)/2 (single multiply)
        // No multi-cycle control needed, compute in 1 cycle
        fact_acc_next = ((idx + 4'd1) * (idx + 4'd2)) >> 1; // i*(i+1)/2
        next_state = STORE;
      end

      STORE: begin
        // Store computed value into result_array[idx]
        if (state == COMPUTE_EVEN) begin
          result_array[idx] = fact_acc;
        end else begin
          result_array[idx] = fact_acc_next; // sum result computed this cycle
        end

        idx_next = idx + 4'd1;
        mul_cycle_next = 8'd0;
        fact_acc_next = 16'd1;

        if (idx + 4'd1 >= n) begin
          // All requested elements are done
          next_state = DONE;
          done = 1'b1;
        end else begin
          // Proceed to next i
          if (((idx + 4'd2) % 2) == 0) next_state = COMPUTE_EVEN;
          else next_state = COMPUTE_ODD;
        end
      end

      DONE: begin
        done = 1'b1;
        if (start_pulse) begin
          next_state = INIT;
        end
      end

      default: begin
        // Maintain defaults
      end
    endcase
  end

endmodule
