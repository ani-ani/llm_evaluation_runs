module max_zebra_length(
  input clk,                  // Clock signal
  input rst_n,                // Active-low reset
  input start,                // Start processing signal
  input [15:0] data_in,       // String bits (0='b', 1='w')
  input [3:0] data_len,       // Actual string length (1-16)
  output reg [4:0] max_streak,// Maximum streak length (1-16)
  output reg done             // High when computation complete
);

  // FSM states
  typedef enum logic [1:0] {
    IDLE               = 2'b00,
    PROCESS_FORWARD    = 2'b01,
    PROCESS_BACKWARD   = 2'b10,
    COMPLETE           = 2'b11
  } state_t;

  state_t current_state, next_state;

  // FSM registers
  logic [4:0] index_f;      // Forward index (0..15)
  logic [4:0] index_b;      // Backward index (15..0)
  logic       prev_bit_fwd; // Previous bit during forward
  logic       prev_bit_bwd; // Previous bit during backward
  logic [4:0] curr_streak_fwd;
  logic [4:0] max_streak_fwd;
  logic [4:0] initial_streak; // Length of first alternating prefix
  logic [4:0] ending_streak;  // Length of last alternating suffix
  logic       first_bit;      // First character of the string (bit 0)
  logic       last_bit;       // Last character of the string (bit data_len-1)

  // Current character during forward/backward processing
  logic       curr_bit_fwd;
  logic       curr_bit_bwd;

  // Control signals
  logic       valid_pos_f;
  logic       valid_pos_b;
  logic       finished_fwd;
  logic       finished_bwd;
  logic       first_last_diff;
  logic       should_run_bwd;

  // State register with synchronous reset
  always_ff @(posedge clk) begin
    if (!rst_n) current_state <= IDLE;
    else         current_state <= next_state;
  end

  // FSM combinational logic
  always_comb begin
    // Defaults
    next_state       = current_state;
    done             = 1'b0;

    unique case (current_state)
      IDLE: begin
        if (start) next_state = PROCESS_FORWARD;
        else       next_state = IDLE;
      end

      PROCESS_FORWARD: begin
        if (finished_fwd) next_state = PROCESS_BACKWARD;
        else              next_state = PROCESS_FORWARD;
      end

      PROCESS_BACKWARD: begin
        if (finished_bwd) next_state = COMPLETE;
        else              next_state = PROCESS_BACKWARD;
      end

      COMPLETE: begin
        done = 1'b1;
        if (start) next_state = PROCESS_FORWARD; // Allow re-start
        else       next_state = COMPLETE;
      end
    endcase
  end

  // Forward pass processing registers (synchronous)
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      index_f          <= 5'd0;
      index_b          <= 5'd15; // Start backward at 15 to ensure immediate exit when should_run_bwd=0
      prev_bit_fwd     <= 1'b0;
      prev_bit_bwd     <= 1'b0;
      curr_streak_fwd  <= 5'd0;
      max_streak_fwd   <= 5'd0;
      initial_streak   <= 5'd0;
      ending_streak    <= 5'd0;
      first_bit        <= 1'b0;
      last_bit         <= 1'b0;
    end
    else if (current_state == IDLE && start) begin
      // Initialize for a new run
      index_f          <= 5'd0;
      index_b          <= 5'd15;
      prev_bit_fwd     <= 1'b0;
      prev_bit_bwd     <= 1'b0;
      curr_streak_fwd  <= 5'd0;
      max_streak_fwd   <= 5'd0;
      initial_streak   <= 5'd0;
      ending_streak    <= 5'd0;
      first_bit        <= 1'b0;
      last_bit         <= 1'b0;
    end
    else begin
      // Hold by default
      index_f          <= index_f;
      index_b          <= index_b;
      prev_bit_fwd     <= prev_bit_fwd;
      prev_bit_bwd     <= prev_bit_bwd;
      curr_streak_fwd  <= curr_streak_fwd;
      max_streak_fwd   <= max_streak_fwd;
      initial_streak   <= initial_streak;
      ending_streak    <= ending_streak;
      first_bit        <= first_bit;
      last_bit         <= last_bit;

      if (current_state == PROCESS_FORWARD) begin
        if (valid_pos_f) begin
          // Capture first and last bits for later use
          if (index_f == 5'd0) begin
            first_bit     <= data_in[0];
            last_bit      <= data_in[data_len - 1];
            prev_bit_fwd  <= data_in[0];
          end

          // Streak update logic
          if (index_f == 5'd0) begin
            curr_streak_fwd <= 5'd1;
            max_streak_fwd  <= 5'd1;
            initial_streak  <= 5'd1;
          end else begin
            if (curr_bit_fwd != prev_bit_fwd) begin
              curr_streak_fwd <= curr_streak_fwd + 1;
            end else begin
              curr_streak_fwd <= 5'd1;
            end
            if (curr_streak_fwd > max_streak_fwd) begin
              max_streak_fwd <= curr_streak_fwd;
            end
            // Initial streak is the length of the first alternating prefix
            if (index_f == 5'd1) begin
              initial_streak <= (curr_bit_fwd != prev_bit_fwd) ? 5'd2 : 5'd1;
            end else if (index_f > 5'd1) begin
              if (curr_bit_fwd == prev_bit_fwd) begin
                // First mismatch observed; freeze initial_streak
                initial_streak <= initial_streak;
              end else begin
                // Still alternating; extend
                initial_streak <= initial_streak + 1;
              end
            end
          end
          prev_bit_fwd <= curr_bit_fwd;
          index_f      <= index_f + 1;
        end else begin
          // Invalid position; just advance to next index
          index_f <= index_f + 1;
        end
      end else if (current_state == PROCESS_BACKWARD) begin
        if (should_run_bwd) begin
          if (valid_pos_b) begin
            if (index_b == data_len - 1) begin
              // Initialize backward from the last position
              prev_bit_bwd  <= data_in[index_b];
              ending_streak <= 5'd1;
            end else begin
              if (curr_bit_bwd != prev_bit_bwd) begin
                ending_streak <= ending_streak + 1;
              end else begin
                ending_streak <= 5'd1;
              end
              prev_bit_bwd <= curr_bit_bwd;
            end
            index_b <= index_b - 1;
          end else begin
            // Invalid position; move on
            index_b <= index_b - 1;
          end
        end
        // If should_run_bwd is 0, we remain in PROCESS_BACKWARD but don't process anything.
      end
    end
  end

  // Derived signals
  assign valid_pos_f       = (index_f < data_len);
  assign curr_bit_fwd      = data_in[index_f[3:0]];

  assign first_last_diff   = (first_bit != last_bit);
  assign should_run_bwd    = (data_len > 1) && first_last_diff;

  assign valid_pos_b       = (index_b < data_len);
  assign curr_bit_bwd      = data_in[index_b[3:0]];

  assign finished_fwd      = (index_f == 5'd16);
  assign finished_bwd      = (should_run_bwd ? (index_b == 5'd15) : 1'b1);

  // Final result register (synchronous, set in COMPLETE)
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      max_streak <= 5'd0;
    end
    else if (current_state == COMPLETE) begin
      if (data_len == 4'd0) begin
        max_streak <= 5'd0;
      end else begin
        // Base is the forward max; candidate adds initial + ending when applicable
        max_streak_fwd <= max_streak_fwd;
        initial_streak <= initial_streak;
        ending_streak  <= ending_streak;
        if (should_run_bwd) begin
          max_streak <= (max_streak_fwd > (initial_streak + ending_streak)) ? max_streak_fwd : (initial_streak + ending_streak);
        end else begin
          max_streak <= max_streak_fwd;
        end
        // Cap at data_len
        if (max_streak > {1'b0, data_len}) begin
          max_streak <= {1'b0, data_len};
        end
      end
    end
  end

endmodule