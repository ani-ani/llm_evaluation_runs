module shell_sort(
  input  wire        clk,
  input  wire        rst_n,
  input  wire        start,
  input  wire [7:0]  data_in [7:0],
  output reg  [7:0]  data_out[7:0],
  output reg         done
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE       = 3'd0,
    LOAD       = 3'd1,
    GAP_CALC   = 3'd2,
    COMPARE    = 3'd3,
    SWAP       = 3'd4,
    UPDATE_GAP = 3'd5,
    DONE       = 3'd6
  } state_t;

  state_t state, next_state;

  // Internal storage for data
  reg [7:0] a [7:0];

  // Shell sort control signals
  reg [2:0] gap_idx;      // 0->gap=4, 1->gap=2, 2->gap=1
  reg [2:0] gap;          // current gap value
  reg [2:0] i;            // outer index
  reg [2:0] j;            // inner index

  // Compare results
  reg do_swap;

  // Gap sequence lookup
  function automatic [2:0] gap_from_idx(input [2:0] idx);
    case (idx)
      3'd0: gap_from_idx = 3'd4;
      3'd1: gap_from_idx = 3'd2;
      3'd2: gap_from_idx = 3'd1;
      default: gap_from_idx = 3'd0;
    endcase
  endfunction

  // Next-state and control logic (combinational)
  always @* begin
    next_state = state;
    do_swap    = 1'b0;

    case (state)
      IDLE: begin
        if (start)
          next_state = LOAD;
      end

      LOAD: begin
        next_state = GAP_CALC;
      end

      GAP_CALC: begin
        // If gap_idx beyond last (2), we're done
        if (gap_idx > 3'd2)
          next_state = DONE;
        else
          next_state = COMPARE;
      end

      COMPARE: begin
        // Determine if we should swap at current j
        if (a[j] < a[j - gap])
          do_swap = 1'b1;

        if (do_swap) begin
          next_state = SWAP;
        end else begin
          // No swap, move j or i or next gap
          if (j >= gap) begin
            next_state = COMPARE; // j will be updated in seq logic
          end else begin
            // inner loop complete for current i
            // advance i or gap
            next_state = UPDATE_GAP;
          end
        end
      end

      SWAP: begin
        // After swap, either continue inner loop or move to UPDATE_GAP
        if (j >= gap)
          next_state = COMPARE; // j will be decreased in seq logic
        else
          next_state = UPDATE_GAP;
      end

      UPDATE_GAP: begin
        // Decide whether to move to next i or next gap
        // Logic realized in sequential block; here we just redirect
        next_state = (gap_idx > 3'd2) ? DONE : COMPARE;
      end

      DONE: begin
        // Stay in DONE until start is deasserted and asserted again
        if (!start)
          next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential logic
  integer k;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= IDLE;
      done     <= 1'b0;
      gap_idx  <= 3'd0;
      gap      <= 3'd0;
      i        <= 3'd0;
      j        <= 3'd0;
      for (k = 0; k < 8; k = k + 1) begin
        a[k]      <= 8'd0;
        data_out[k] <= 8'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done    <= 1'b0;
          gap_idx <= 3'd0;
          gap     <= 3'd0;
          i       <= 3'd0;
          j       <= 3'd0;
        end

        LOAD: begin
          // Load input data into internal array
          for (k = 0; k < 8; k = k + 1) begin
            a[k] <= data_in[k];
          end
          done    <= 1'b0;
          gap_idx <= 3'd0;
          gap     <= 3'd0;
          i       <= 3'd0;
          j       <= 3'd0;
        end

        GAP_CALC: begin
          // Set current gap from sequence
          gap <= gap_from_idx(gap_idx);
          // Initialize outer loop index i = gap
          if (gap_from_idx(gap_idx) != 3'd0) begin
            i <= gap_from_idx(gap_idx);
            j <= gap_from_idx(gap_idx);
          end
        end

        COMPARE: begin
          // Inner loop of Shell sort
          // do_swap already computed in combinational logic
          if (a[j] < a[j - gap]) begin
            // schedule swap in SWAP state
          end else begin
            // No swap at this j, move j backward if possible
            if (j >= gap) begin
              j <= j - gap;
            end else begin
              // Finished inner loop for this i, move to next i in UPDATE_GAP
            end
          end
        end

        SWAP: begin
          // Perform swap between a[j] and a[j-gap]
          reg [7:0] temp;
          temp       <= a[j];
          a[j]       <= a[j - gap];
          a[j - gap] <= temp;

          // After swap, continue inner loop if possible
          if (j >= gap)
            j <= j - gap;
        end

        UPDATE_GAP: begin
          // Decide advancement of i or gap based on current i and gap
          if (i < 3'd7) begin
            // Move to next i
            i <= i + 3'd1;
            j <= i + 3'd1; // next j starts at new i
          end else begin
            // Completed all i for this gap, move to next gap
            gap_idx <= gap_idx + 3'd1;
            if (gap_idx + 3'd1 <= 3'd2) begin
              // Prepare for next gap
              gap <= gap_from_idx(gap_idx + 3'd1);
              i   <= gap_from_idx(gap_idx + 3'd1);
              j   <= gap_from_idx(gap_idx + 3'd1);
            end
          end
        end

        DONE: begin
          // Latch sorted data to output
          for (k = 0; k < 8; k = k + 1) begin
            data_out[k] <= a[k];
          end
          done <= 1'b1;
        end

        default: begin
          // Should not occur; reset-like behavior
          done    <= 1'b0;
          gap_idx <= 3'd0;
          gap     <= 3'd0;
          i       <= 3'd0;
          j       <= 3'd0;
        end
      endcase
    end
  end

endmodule