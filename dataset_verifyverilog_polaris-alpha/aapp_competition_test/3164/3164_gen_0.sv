module longest_twice_subarray(
  input clk,
  input rst_n,
  input start,
  input [3:0] arr [0:7],
  output reg [3:0] max_length,
  output reg done
);

  // State machine encoding
  localparam IDLE       = 2'd0;
  localparam INIT       = 2'd1;
  localparam PROCESS    = 2'd2;
  localparam FINISH     = 2'd3;

  reg [1:0] state, next_state;

  // Internal array storage
  reg [3:0] arr_reg [0:7];

  // Frequency counters for values 0-15, 2 bits each
  reg [1:0] freq [0:15];

  // Sliding window pointers
  reg [3:0] left;
  reg [3:0] right;

  // Current window length
  reg [3:0] window_len;

  // Cycle counter to ensure done is asserted exactly 15 cycles after start
  reg [3:0] cycle_cnt;

  // Helper signals
  reg [3:0] curr_val;
  reg [3:0] left_val;
  reg       shrink;
  reg       all_nonzero_eq2;

  integer i;

  // Combinational: determine if all non-zero frequencies are exactly 2
  always @* begin
    all_nonzero_eq2 = 1'b1;
    for (i = 0; i < 16; i = i + 1) begin
      if (freq[i] != 2'd0 && freq[i] != 2'd2) begin
        all_nonzero_eq2 = 1'b0;
      end
    end
  end

  // Combinational: shrink decision (when freq of current exceeds 2)
  always @* begin
    if (state == PROCESS && right < 8) begin
      curr_val = arr_reg[right];
      if ((freq[curr_val] + 2'd1) > 2'd2) begin
        shrink = 1'b1;
      end else begin
        shrink = 1'b0;
      end
    end else begin
      shrink = 1'b0;
    end
  end

  // Next state logic
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = INIT;
        end
      end
      INIT: begin
        next_state = PROCESS;
      end
      PROCESS: begin
        if (cycle_cnt == 4'd14) begin
          next_state = FINISH;
        end else begin
          next_state = PROCESS;
        end
      end
      FINISH: begin
        if (!start) begin
          next_state = IDLE;
        end else begin
          next_state = FINISH;
        end
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      max_length  <= 4'd0;
      done        <= 1'b0;
      left        <= 4'd0;
      right       <= 4'd0;
      window_len  <= 4'd0;
      cycle_cnt   <= 4'd0;
      for (i = 0; i < 16; i = i + 1) begin
        freq[i] <= 2'd0;
      end
      for (i = 0; i < 8; i = i + 1) begin
        arr_reg[i] <= 4'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done       <= 1'b0;
          max_length <= max_length; // hold
          if (start) begin
            // Capture array on start
            for (i = 0; i < 8; i = i + 1) begin
              arr_reg[i] <= arr[i];
            end
            // Prepare for INIT
          end
        end

        INIT: begin
          // Initialize all counters and pointers
          for (i = 0; i < 16; i = i + 1) begin
            freq[i] <= 2'd0;
          end
          left       <= 4'd0;
          right      <= 4'd0;
          window_len <= 4'd0;
          max_length <= 4'd0;
          cycle_cnt  <= 4'd0;
          done       <= 1'b0;
        end

        PROCESS: begin
          cycle_cnt <= cycle_cnt + 4'd1;

          if (right < 8) begin
            curr_val <= arr_reg[right];

            if (shrink) begin
              // Shrink from left until adding curr_val is valid
              if (left < right) begin
                left_val <= arr_reg[left];
                // decrement freq of element at left
                if (freq[left_val] != 2'd0) begin
                  freq[left_val] <= freq[left_val] - 2'd1;
                end
                left <= left + 4'd1;
              end
            end else begin
              // Safe to include current element
              freq[curr_val] <= freq[curr_val] + 2'd1;
              right          <= right + 4'd1;
            end
          end

          // Update window length (right - left)
          window_len <= right - left;

          // Check and update max_length when all non-zero freq == 2
          if (all_nonzero_eq2 && window_len > max_length) begin
            max_length <= window_len;
          end

          // done is asserted in FINISH state, keep low here
          done <= 1'b0;
        end

        FINISH: begin
          // Assert done exactly at/after 15th cycle from start
          done <= 1'b1;
          // Hold max_length stable
          max_length <= max_length;
          // Hold others
          left  <= left;
          right <= right;
          window_len <= window_len;
          cycle_cnt <= cycle_cnt;
        end

        default: begin
          // Safety defaults
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule