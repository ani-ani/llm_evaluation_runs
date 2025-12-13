module min_subsegment_removal(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [31:0] a[0:7],
  output reg [3:0] min_size,
  output reg done
);

  // Internal storage for input array
  reg [31:0] arr[0:7];

  // FSM states
  typedef enum logic [1:0] {
    IDLE          = 2'b00,
    CHECK_UNIQUE  = 2'b01,
    CALCULATE     = 2'b10,
    DONE          = 2'b11
  } state_t;

  state_t state, next_state;

  // Indices for subsegment iteration
  reg [2:0] l_idx, r_idx;

  // Flag results from uniqueness checking
  reg unique_all;
  reg unique_remain;

  // Control flags
  reg started;

  // ---------------------------------------------------------------------------
  // Combinational: Parallel uniqueness check logic
  // ---------------------------------------------------------------------------
  // unique_all: all elements in arr[0:n-1] are unique
  // unique_remain: all remaining elements outside [l_idx, r_idx] are unique

  integer i, j;

  always @* begin
    // Default
    unique_all    = 1'b1;
    unique_remain = 1'b1;

    // Check all unique for indices [0, n-1]
    for (i = 0; i < 8; i = i + 1) begin
      if (i < n) begin
        for (j = i + 1; j < 8; j = j + 1) begin
          if (j < n) begin
            if (arr[i] == arr[j]) begin
              unique_all = 1'b0;
            end
          end
        end
      end
    end

    // Check uniqueness of remaining elements when removing [l_idx, r_idx]
    // We compare only indices < n and not in [l_idx, r_idx]
    for (i = 0; i < 8; i = i + 1) begin
      if ((i < n) && !((i >= l_idx) && (i <= r_idx))) begin
        for (j = i + 1; j < 8; j = j + 1) begin
          if ((j < n) && !((j >= l_idx) && (j <= r_idx))) begin
            if (arr[i] == arr[j]) begin
              unique_remain = 1'b0;
            end
          end
        end
      end
    end
  end

  // ---------------------------------------------------------------------------
  // Sequential: State register and outputs
  // ---------------------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      done      <= 1'b0;
      min_size  <= 4'd0;
      l_idx     <= 3'd0;
      r_idx     <= 3'd0;
      started   <= 1'b0;
      arr[0]    <= 32'd0;
      arr[1]    <= 32'd0;
      arr[2]    <= 32'd0;
      arr[3]    <= 32'd0;
      arr[4]    <= 32'd0;
      arr[5]    <= 32'd0;
      arr[6]    <= 32'd0;
      arr[7]    <= 32'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start && !started) begin
            // Latch inputs
            arr[0] <= a[0];
            arr[1] <= a[1];
            arr[2] <= a[2];
            arr[3] <= a[3];
            arr[4] <= a[4];
            arr[5] <= a[5];
            arr[6] <= a[6];
            arr[7] <= a[7];
            min_size <= 4'd15; // large initial value
            l_idx <= 3'd0;
            r_idx <= 3'd0;
            started <= 1'b1;
          end
          else if (!start) begin
            started <= 1'b0;
          end
        end

        CHECK_UNIQUE: begin
          // unique_all is valid combinationally based on latched arr/n
          if (unique_all) begin
            min_size <= 4'd0;
          end else begin
            // Initialize for CALCULATE
            min_size <= 4'd15; // re-init as safety
            l_idx    <= 3'd0;
            r_idx    <= 3'd0;
          end
        end

        CALCULATE: begin
          // For current (l_idx, r_idx), unique_remain is valid combinationally
          if (unique_remain) begin
            if ((r_idx >= l_idx) && ((r_idx - l_idx + 1) < min_size)) begin
              min_size <= r_idx - l_idx + 1;
            end
          end

          // Subsegment iteration: advance r_idx, then l_idx
          if (n == 3'd0) begin
            // Edge case: no elements
          end else begin
            if (r_idx + 1 < n) begin
              r_idx <= r_idx + 1'b1;
            end else begin
              if (l_idx + 1 < n) begin
                l_idx <= l_idx + 1'b1;
                r_idx <= l_idx + 1'b0; // next r starts at new l_idx
              end
            end
          end
        end

        DONE: begin
          done <= 1'b1;
          // Wait for start to be deasserted before returning to IDLE (handled in next_state)
        end

        default: begin
          // Should not occur
        end
      endcase
    end
  end

  // ---------------------------------------------------------------------------
  // Next-state logic
  // ---------------------------------------------------------------------------
  always @* begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start && !started) begin
          next_state = CHECK_UNIQUE;
        end
      end

      CHECK_UNIQUE: begin
        if (unique_all) begin
          next_state = DONE;
        end else begin
          next_state = CALCULATE;
        end
      end

      CALCULATE: begin
        // Terminate when all (l,r) pairs for 0 <= l <= r < n have been checked
        if (n == 3'd0) begin
          next_state = DONE;
        end else begin
          if ((l_idx == (n - 1)) && (r_idx == (n - 1))) begin
            next_state = DONE;
          end else begin
            next_state = CALCULATE;
          end
        end
      end

      DONE: begin
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