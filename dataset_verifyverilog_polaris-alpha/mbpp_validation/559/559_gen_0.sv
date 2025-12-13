module max_subarray_sum (
  input clk,
  input rst_n,
  input start,
  input signed [4:0] a [0:7],
  output reg signed [4:0] max_sum,
  output reg done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    INIT  = 2'b01,
    CALC  = 2'b10,
    DONE  = 2'b11
  } state_t;

  state_t state, next_state;

  reg [3:0] idx;  // index for 8 elements (0-7)
  reg signed [4:0] max_so_far;
  reg signed [4:0] max_ending_here;

  // Sequential logic: state, registers, async reset
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= IDLE;
      idx             <= 4'd0;
      max_so_far      <= 5'sd0;
      max_ending_here <= 5'sd0;
      max_sum         <= 5'sd0;
      done            <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Move to INIT in next_state; actual init happens in INIT
          end
        end

        INIT: begin
          // Initialize for Kadane's algorithm
          idx             <= 4'd0;
          max_so_far      <= 5'sd0;
          max_ending_here <= 5'sd0;
          done            <= 1'b0;
        end

        CALC: begin
          // Process a[idx]
          max_ending_here <= max_ending_here + a[idx];

          // Apply Kadane's rules using previous cycle values via if/else
          if ((max_ending_here + a[idx]) < 0) begin
            max_ending_here <= 5'sd0;
          end else if ((max_ending_here + a[idx]) > max_so_far) begin
            max_so_far <= max_ending_here + a[idx];
          end

          // Increment index
          idx <= idx + 4'd1;
        end

        DONE: begin
          max_sum <= max_so_far;
          done    <= 1'b1;
        end

        default: begin
          // Safe defaults
          done <= 1'b0;
        end
      endcase
    end
  end

  // Combinational next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = INIT;
      end

      INIT: begin
        // After init, start calculations
        next_state = CALC;
      end

      CALC: begin
        // After processing 8 elements, go to DONE
        if (idx == 4'd7)
          next_state = DONE;
        else
          next_state = CALC;
      end

      DONE: begin
        // Wait for start to be deasserted then reasserted for next operation
        if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule