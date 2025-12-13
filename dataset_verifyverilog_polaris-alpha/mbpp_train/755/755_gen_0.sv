module second_smallest (
  input  logic              clk,
  input  logic              rst_n,
  input  logic              start,
  input  logic [15:0]       numbers [0:7],
  output logic [15:0]       result,
  output logic              valid,
  output logic              done
);

  typedef enum logic [1:0] {
    IDLE        = 2'b00,
    REMOVE_DUPS= 2'b01,
    SORT        = 2'b10,
    OUTPUT      = 2'b11
  } state_t;

  state_t            state, next_state;

  logic [15:0]       unique_vals [0:7];
  logic [2:0]        unique_count;

  logic [2:0]        dup_i;
  logic [2:0]        dup_j;
  logic              is_dup;

  logic [2:0]        sort_i;
  logic [2:0]        sort_j;
  logic [15:0]       temp_swap;

  logic [4:0]        cycle_cnt;

  // Combinational duplicate-check for current dup_j against unique_vals[0:dup_i-1]
  function logic check_duplicate(
    input logic [15:0] val,
    input logic [2:0]  count
  );
    logic dup_flag;
    integer k;
    begin
      dup_flag = 1'b0;
      for (k = 0; k < 8; k = k + 1) begin
        if (k < count) begin
          if (unique_vals[k] == val)
            dup_flag = 1'b1;
        end
      end
      check_duplicate = dup_flag;
    end
  endfunction

  // Next-state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = REMOVE_DUPS;
      end

      REMOVE_DUPS: begin
        // When we've processed all 8 inputs, move to SORT
        if (dup_j == 3'd7)
          next_state = SORT;
      end

      SORT: begin
        // Bubble sort completion condition
        if (sort_i == 3'd7)
          next_state = OUTPUT;
      end

      OUTPUT: begin
        // Single-cycle output, then back to IDLE
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      result       <= 16'd0;
      valid        <= 1'b0;
      done         <= 1'b0;
      unique_count <= 3'd0;
      dup_i        <= 3'd0;
      dup_j        <= 3'd0;
      sort_i       <= 3'd0;
      sort_j       <= 3'd0;
      cycle_cnt    <= 5'd0;

      unique_vals[0] <= 16'd0;
      unique_vals[1] <= 16'd0;
      unique_vals[2] <= 16'd0;
      unique_vals[3] <= 16'd0;
      unique_vals[4] <= 16'd0;
      unique_vals[5] <= 16'd0;
      unique_vals[6] <= 16'd0;
      unique_vals[7] <= 16'd0;
    end else begin
      state <= next_state;

      // Default outputs each cycle
      done  <= 1'b0;

      case (state)
        IDLE: begin
          valid        <= 1'b0;
          result       <= 16'd0;
          cycle_cnt    <= 5'd0;

          if (start) begin
            // Initialize for duplicate removal
            unique_count <= 3'd0;
            dup_i        <= 3'd0;
            dup_j        <= 3'd0;

            unique_vals[0] <= 16'd0;
            unique_vals[1] <= 16'd0;
            unique_vals[2] <= 16'd0;
            unique_vals[3] <= 16'd0;
            unique_vals[4] <= 16'd0;
            unique_vals[5] <= 16'd0;
            unique_vals[6] <= 16'd0;
            unique_vals[7] <= 16'd0;
          end
        end

        REMOVE_DUPS: begin
          cycle_cnt <= cycle_cnt + 5'd1;

          // For current input numbers[dup_j], check if duplicate
          is_dup = check_duplicate(numbers[dup_j], dup_i);

          if (!is_dup) begin
            unique_vals[dup_i] <= numbers[dup_j];
            dup_i              <= dup_i + 3'd1;
            unique_count       <= dup_i + 3'd1;
          end

          if (dup_j < 3'd7) begin
            dup_j <= dup_j + 3'd1;
          end

          // If all inputs processed, prepare sort indices
          if (dup_j == 3'd7) begin
            sort_i <= 3'd0;
            sort_j <= 3'd0;
          end
        end

        SORT: begin
          cycle_cnt <= cycle_cnt + 5'd1;

          // Bubble sort over unique_vals[0 : unique_count-1]
          if (unique_count > 3'd1) begin
            if (sort_i < unique_count - 1) begin
              if (sort_j < unique_count - 1 - sort_i) begin
                if (unique_vals[sort_j] > unique_vals[sort_j + 1]) begin
                  temp_swap                  = unique_vals[sort_j];
                  unique_vals[sort_j]        <= unique_vals[sort_j + 1];
                  unique_vals[sort_j + 1]    <= temp_swap;
                end
                sort_j <= sort_j + 3'd1;
              end else begin
                sort_j <= 3'd0;
                sort_i <= sort_i + 3'd1;
              end
            end else begin
              // Sorting completed
              sort_i <= 3'd7; // Trigger transition condition
            end
          end else begin
            // If 0 or 1 unique elements, no sorting needed
            sort_i <= 3'd7; // Trigger transition to OUTPUT
          end
        end

        OUTPUT: begin
          cycle_cnt <= cycle_cnt + 5'd1;

          if (unique_count >= 3'd2) begin
            result <= unique_vals[1];
            valid  <= 1'b1;
          end else begin
            result <= 16'd0;
            valid  <= 1'b0;
          end

          done <= 1'b1; // Single-cycle pulse
        end

        default: begin
          // Should not occur; safe defaults
          valid     <= 1'b0;
          done      <= 1'b0;
          result    <= 16'd0;
        end
      endcase
    end
  end

endmodule