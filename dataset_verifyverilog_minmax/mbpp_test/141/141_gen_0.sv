module pancake_sort (
  input clk,
  input rst_n,
  input start,
  input [7:0] data_in [7:0],
  output reg [7:0] sorted [7:0],
  output reg done
);

  // FSM states
  typedef enum logic [2:0] {
    IDLE      = 3'b000,
    FIND_MAX  = 3'b001,
    FLIP1     = 3'b010,
    FLIP2     = 3'b011,
    DECREMENT = 3'b100,
    DONE      = 3'b101
  } state_t;

  state_t state, next_state;

  // Internal working array and control signals
  reg [7:0] work [7:0];
  reg [2:0] size;        // 3-bit counter for current subarray size (8..1)
  reg [2:0] max_idx;     // index of the maximum element in current prefix
  reg [2:0] max_idx_combo; // comb. version to sample on state transition

  // Find max index in the first 'size' elements (combinational)
  always_comb begin
    max_idx_combo = 3'b0;
    if (size >= 3'b001) begin
      max_idx_combo = 3'b0;
      for (int i = 1; i < 8; i++) begin
        if (i < size) begin
          if (work[i] > work[max_idx_combo]) begin
            max_idx_combo = i[2:0];
          end
        end
      end
    end
  end

  // State transition logic (combinational)
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = FIND_MAX;
        else       next_state = IDLE;
      end
      FIND_MAX: next_state = FLIP1;
      FLIP1:    next_state = FLIP2;
      FLIP2:    next_state = DECREMENT;
      DECREMENT: begin
        if (size > 3'b001) next_state = FIND_MAX;
        else               next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
        else        next_state = DONE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic with active-low reset
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done  <= 1'b0;
      size  <= 3'b000; // undefined until start; will be set in IDLE on start
      max_idx <= 3'b000;
      for (int i = 0; i < 8; i++) work[i] <= 8'h00;
      for (int i = 0; i < 8; i++) sorted[i] <= 8'h00;
    end else begin
      // Advance state
      state <= next_state;

      // State actions
      case (next_state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Initialize working array with input data
            for (int i = 0; i < 8; i++) work[i] <= data_in[i];
            size <= 3'b111; // start with 8
            max_idx <= 3'b000; // will be set in FIND_MAX next cycle
          end
        end

        FIND_MAX: begin
          // Capture the computed max index for this cycle
          max_idx <= max_idx_combo;
        end

        FLIP1: begin
          // Flip prefix [0..max_idx]
          if (max_idx > 3'b000) begin
            for (int i = 0; i < 4; i++) begin // only need up to mid of max_idx (max 7)
              if (i < max_idx) begin
                int j;
                j = max_idx - i;
                if (i < j) begin
                  reg [7:0] tmp;
                  tmp = work[i];
                  work[i] = work[j];
                  work[j] = tmp;
                end
              end
            end
          end
        end

        FLIP2: begin
          // Flip prefix [0..size-1]
          if (size > 3'b001) begin
            int limit;
            limit = size - 1; // 3-bit value (0..7)
            for (int i = 0; i < 4; i++) begin
              if (i < limit) begin
                int j;
                j = limit - i;
                if (i < j) begin
                  reg [7:0] tmp;
                  tmp = work[i];
                  work[i] = work[j];
                  work[j] = tmp;
                end
              end
            end
          end
        end

        DECREMENT: begin
          size <= size - 1;
        end

        DONE: begin
          done <= 1'b1;
          // Latch final sorted result
          for (int i = 0; i < 8; i++) sorted[i] <= work[i];
        end

        default: ; // no-op
      endcase
    end
  end

endmodule
