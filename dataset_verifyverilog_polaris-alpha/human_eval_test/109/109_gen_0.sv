module check_right_shift_sort(
  input        clk,
  input        rst_n,
  input        start,
  input  [7:0] arr_size,
  input  [15:0] arr [7:0],
  output reg   result,
  output reg   done
);

  // State encoding
  localparam IDLE       = 2'b00;
  localparam CHECK_SHIFT= 2'b01;
  localparam EVALUATE   = 2'b10;
  localparam COMPLETE   = 2'b11;

  reg [1:0] state, next_state;

  // Registers
  reg [7:0] shift_idx;          // current rotation index
  reg [7:0] check_pos;          // index within array for comparison
  reg       sorted_for_shift;   // flag for current rotation
  reg       any_sorted;         // flag if any rotation sorted

  // Synchronous state and output/control registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state            <= IDLE;
      result           <= 1'b0;
      done             <= 1'b0;
      shift_idx        <= 8'd0;
      check_pos        <= 8'd0;
      sorted_for_shift <= 1'b0;
      any_sorted       <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          // Hold result and done until a new start
          if (start) begin
            done       <= 1'b0;
            any_sorted <= 1'b0;
            shift_idx  <= 8'd0;
            check_pos  <= 8'd0;

            if (arr_size == 8'd0) begin
              // Empty array is trivially sortable
              result <= 1'b1;
              done   <= 1'b1;
            end else begin
              // Initialize for first shift check
              sorted_for_shift <= 1'b1;
            end
          end
        end

        CHECK_SHIFT: begin
          // For the current shift_idx, we check pair at check_pos and check_pos+1
          // Effective index with rotation by right shift_idx:
          // idx(i) = (i - shift_idx + arr_size) % arr_size
          if (arr_size <= 8'd1) begin
            // Trivially sorted if 0 or 1 element
            sorted_for_shift <= 1'b1;
          end else begin
            if (check_pos < (arr_size - 1)) begin
              // Compute rotated indices
              integer idx_a, idx_b;
              idx_a = (check_pos - shift_idx + arr_size);
              idx_b = (check_pos + 1 - shift_idx + arr_size);
              idx_a = idx_a % arr_size;
              idx_b = idx_b % arr_size;

              if (arr[idx_a] > arr[idx_b]) begin
                sorted_for_shift <= 1'b0;
              end

              check_pos <= check_pos + 1'b1;
            end
          end
        end

        EVALUATE: begin
          // Decide based on current rotation check
          if (sorted_for_shift) begin
            any_sorted <= 1'b1;
          end

          if (shift_idx + 1 < arr_size && !any_sorted && arr_size > 0) begin
            // Prepare next rotation
            shift_idx        <= shift_idx + 1'b1;
            check_pos        <= 8'd0;
            sorted_for_shift <= 1'b1;
          end else begin
            // No more shifts or already found sorted
            // Result and done will be set in COMPLETE
          end
        end

        COMPLETE: begin
          result <= (arr_size == 0) ? 1'b1 : any_sorted;
          done   <= 1'b1;
        end

        default: begin
          // Should not occur
          state <= IDLE;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (!rst_n) begin
          next_state = IDLE;
        end else if (start) begin
          if (arr_size == 8'd0) begin
            next_state = COMPLETE; // immediate completion for size 0
          end else begin
            next_state = CHECK_SHIFT;
          end
        end else begin
          next_state = IDLE;
        end
      end

      CHECK_SHIFT: begin
        if (arr_size <= 8'd1) begin
          // Trivial, move directly to EVALUATE
          next_state = EVALUATE;
        end else if (check_pos >= (arr_size - 1)) begin
          // Completed comparisons for this shift
          next_state = EVALUATE;
        end else begin
          next_state = CHECK_SHIFT;
        end
      end

      EVALUATE: begin
        // If we found a sorted rotation or exhausted all shifts, go COMPLETE
        // else continue with next CHECK_SHIFT
        if ((shift_idx + 1 < arr_size) && !any_sorted && (arr_size > 0)) begin
          next_state = CHECK_SHIFT;
        end else begin
          next_state = COMPLETE;
        end
      end

      COMPLETE: begin
        // Wait here until a new start; then go to IDLE to re-initialize
        if (start) begin
          next_state = IDLE;
        end else begin
          next_state = COMPLETE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule