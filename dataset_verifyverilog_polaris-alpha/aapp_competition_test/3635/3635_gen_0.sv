module max_executives(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [3:0]  N,
  input  logic [15:0] bananas [0:7],
  output logic [3:0]  k,
  output logic        done
);

  typedef enum logic [2:0] {
    IDLE    = 3'd0,
    INIT    = 3'd1,
    ACCUM   = 3'd2,
    COMPARE = 3'd3,
    DONE_ST = 3'd4
  } state_t;

  state_t        state, next_state;

  logic [3:0]    index;
  logic [3:0]    valid_segments;
  logic [15:0]   current_sum;
  logic [15:0]   last_sum;
  logic [15:0]   next_current_sum;
  logic [15:0]   next_last_sum;
  logic [3:0]    next_index;
  logic [3:0]    next_valid_segments;
  logic [3:0]    next_k;
  logic          next_done;

  // Next-state combinational logic
  always_comb begin
    // Default assignments (hold state)
    next_state          = state;
    next_index          = index;
    next_valid_segments = valid_segments;
    next_current_sum    = current_sum;
    next_last_sum       = last_sum;
    next_k              = k;
    next_done           = done;

    case (state)
      IDLE: begin
        next_done = 1'b0;
        if (start) begin
          next_state          = INIT;
        end
      end

      INIT: begin
        // Initialize as specified
        next_index          = 4'd0;
        next_valid_segments = 4'd0;
        next_current_sum    = 16'd0;
        next_last_sum       = 16'd0;
        next_k              = 4'd0;
        next_done           = 1'b0;
        // Move to accumulation if N > 0, else go to DONE
        if (N != 4'd0)
          next_state = ACCUM;
        else
          next_state = DONE_ST;
      end

      ACCUM: begin
        // Accumulate current briefcase
        if (index < N) begin
          next_current_sum = current_sum + bananas[index];
          next_state       = COMPARE;
        end else begin
          // All processed
          next_state = DONE_ST;
        end
      end

      COMPARE: begin
        if (current_sum >= last_sum && current_sum != 16'd0) begin
          // valid segment when current_sum (after ACCUM) >= last_sum
          next_valid_segments = valid_segments + 4'd1;
          next_last_sum       = current_sum;
          next_current_sum    = 16'd0;
        end
        // Move to next index
        if (index + 4'd1 < N) begin
          next_index = index + 4'd1;
          next_state = ACCUM;
        end else begin
          next_index = index + 4'd1;
          next_state = DONE_ST;
        end
      end

      DONE_ST: begin
        // Latch result and signal done
        next_k    = valid_segments;
        next_done = 1'b1;
        // Stay in DONE_ST until new start
        if (start) begin
          next_state = INIT;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential logic with async active-low reset
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= IDLE;
      index           <= 4'd0;
      valid_segments  <= 4'd0;
      current_sum     <= 16'd0;
      last_sum        <= 16'd0;
      k               <= 4'd0;
      done            <= 1'b0;
    end else begin
      state           <= next_state;
      index           <= next_index;
      valid_segments  <= next_valid_segments;
      current_sum     <= next_current_sum;
      last_sum        <= next_last_sum;
      k               <= next_k;
      done            <= next_done;
    end
  end

endmodule