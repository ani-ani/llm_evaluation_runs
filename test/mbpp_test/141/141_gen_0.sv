module pancake_sort (
  input              clk,
  input              rst_n,
  input              start,
  input      [7:0]   data_in [7:0],
  output reg [7:0]   sorted  [7:0],
  output reg         done
);

  // FSM States
  typedef enum logic [2:0] {
    IDLE      = 3'd0,
    FIND_MAX  = 3'd1,
    FLIP1     = 3'd2,
    FLIP2     = 3'd3,
    DECREMENT = 3'd4,
    DONE      = 3'd5
  } state_t;

  state_t state, next_state;

  // Working array
  reg [7:0] work [7:0];

  // Control registers
  reg [2:0] curr_size;        // current subarray size-1 (0..7), actual size = curr_size + 1
  reg [2:0] max_idx;          // index of maximum element in current range
  reg [7:0] max_val;          // maximum value in current range
  reg [2:0] idx;              // general index for find max
  reg [2:0] flip_left;        // left index for flip
  reg [2:0] flip_right;       // right index for flip

  integer i;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      done       <= 1'b0;
      curr_size  <= 3'd0;
      max_idx    <= 3'd0;
      max_val    <= 8'd0;
      idx        <= 3'd0;
      flip_left  <= 3'd0;
      flip_right <= 3'd0;
      for (i = 0; i < 8; i = i + 1) begin
        work[i]   <= 8'd0;
        sorted[i] <= 8'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Load input data into working array
            for (i = 0; i < 8; i = i + 1) begin
              work[i] <= data_in[i];
            end
            // Initialize for FIND_MAX
            curr_size  <= 3'd7;        // start with size 8 (indices 0..7)
            idx        <= 3'd1;        // start scanning from index 1
            max_idx    <= 3'd0;
            max_val    <= data_in[0];  // initial max is element 0
          end
        end

        FIND_MAX: begin
          // Single-cycle linear search for max in 0..curr_size
          max_val <= work[0];
          max_idx <= 3'd0;
          for (i = 1; i < 8; i = i + 1) begin
            if (i <= curr_size) begin
              if (work[i] > max_val) begin
                max_val <= work[i];
                max_idx <= i[2:0];
              end
            end
          end
        end

        FLIP1: begin
          // Flip from 0 to max_idx (inclusive) in one cycle
          flip_left  <= 3'd0;
          flip_right <= max_idx;
          for (i = 0; i < 8; i = i + 1) begin
            // default: hold
            work[i] <= work[i];
          end
          for (i = 0; i < 8; i = i + 1) begin
            if ((i >= flip_left) && (i <= flip_right)) begin
              work[i] <= work[flip_left + flip_right - i];
            end
          end
        end

        FLIP2: begin
          // Flip from 0 to curr_size (inclusive) in one cycle
          flip_left  <= 3'd0;
          flip_right <= curr_size;
          for (i = 0; i < 8; i = i + 1) begin
            // default: hold
            work[i] <= work[i];
          end
          for (i = 0; i < 8; i = i + 1) begin
            if ((i >= flip_left) && (i <= flip_right)) begin
              work[i] <= work[flip_left + flip_right - i];
            end
          end
        end

        DECREMENT: begin
          if (curr_size != 3'd0) begin
            curr_size <= curr_size - 3'd1;
          end
          // Prepare for next FIND_MAX if needed
          if (curr_size > 3'd0) begin
            max_val <= work[0];
            max_idx <= 3'd0;
            idx     <= 3'd1;
          end
        end

        DONE: begin
          done <= 1'b1;
          for (i = 0; i < 8; i = i + 1) begin
            sorted[i] <= work[i];
          end
        end

        default: begin
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = FIND_MAX;
        end else begin
          next_state = IDLE;
        end
      end

      FIND_MAX: begin
        // After combinational max search, go to first flip
        // If curr_size == 0 or 1, array is sorted
        if (curr_size <= 3'd0) begin
          next_state = DONE;
        end else begin
          next_state = FLIP1;
        end
      end

      FLIP1: begin
        // If max already at end (max_idx == curr_size), skip FLIP2
        if (max_idx == curr_size) begin
          next_state = DECREMENT;
        end else begin
          next_state = FLIP2;
        end
      end

      FLIP2: begin
        next_state = DECREMENT;
      end

      DECREMENT: begin
        if (curr_size <= 3'd0) begin
          next_state = DONE;
        end else begin
          next_state = FIND_MAX;
        end
      end

      DONE: begin
        // Stay in DONE until start deasserts and asserts again
        if (!start) begin
          next_state = IDLE;
        end else begin
          next_state = DONE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule