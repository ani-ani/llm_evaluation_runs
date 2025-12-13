module kth_element (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [7:0]  k,
  input  logic [7:0]  arr [7:0],
  output logic [7:0]  result,
  output logic        done
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE        = 3'd0,
    LOAD_DATA   = 3'd1,
    OUTER_LOOP  = 3'd2,
    INNER_LOOP  = 3'd3,
    COMPARE     = 3'd4,
    SWAP        = 3'd5,
    DONE        = 3'd6
  } state_t;

  state_t       state, next_state;
  logic [7:0]   data [7:0];
  logic [2:0]   i, j;          // loop indices: 0..7
  logic [7:0]   k_reg;         // latched k
  logic [7:0]   temp;          // for swap
  logic         cmp_gt;        // comparison result

  // Sequential logic: state, counters, data, k_reg, result, done
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= IDLE;
      i       <= 3'd0;
      j       <= 3'd0;
      k_reg   <= 8'd0;
      result  <= 8'd0;
      done    <= 1'b1;  // ready after reset
    end else begin
      state <= next_state;

      // Default done deassert; override only when entering DONE
      done <= 1'b0;

      case (state)
        IDLE: begin
          if (start) begin
            // Capture k on start
            k_reg <= k;
          end
        end

        LOAD_DATA: begin
          // Copy input array into internal registers
          data[0] <= arr[0];
          data[1] <= arr[1];
          data[2] <= arr[2];
          data[3] <= arr[3];
          data[4] <= arr[4];
          data[5] <= arr[5];
          data[6] <= arr[6];
          data[7] <= arr[7];
          i       <= 3'd0;
          j       <= 3'd0;
        end

        OUTER_LOOP: begin
          // Set up inner loop start for this i
          j <= 3'd0;
        end

        INNER_LOOP: begin
          // j increment handled in COMPARE/SWAP next_state logic
        end

        COMPARE: begin
          // Comparison is combinational (cmp_gt), no state updates here
        end

        SWAP: begin
          // Conditionally swap based on cmp_gt
          if (cmp_gt) begin
            temp      <= data[j];
            data[j]   <= data[j+1];
            data[j+1] <= temp;
          end
        end

        DONE: begin
          // Output kth smallest (1-based index)
          // Assumes k_reg is 1..8 as specified
          result <= data[k_reg - 1];
          done   <= 1'b1;  // assert done for this cycle
        end

        default: begin
        end
      endcase
    end
  end

  // Combinational compare
  always_comb begin
    if (state == COMPARE || state == SWAP) begin
      cmp_gt = (data[j] > data[j+1]);
    end else begin
      cmp_gt = 1'b0;
    end
  end

  // Next-state logic and loop control
  always_comb begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = LOAD_DATA;
        end else begin
          next_state = IDLE;
        end
      end

      LOAD_DATA: begin
        // Initialize outer loop
        next_state = OUTER_LOOP;
      end

      OUTER_LOOP: begin
        if (i < 3'd7) begin
          // Start inner loop for this i
          next_state = INNER_LOOP;
        end else begin
          // All passes done -> go to DONE
          next_state = DONE;
        end
      end

      INNER_LOOP: begin
        // For current i, run j from 0 to 6-i; each iteration uses COMPARE->SWAP
        if (j <= (3'd6 - i)) begin
          next_state = COMPARE;
        end else begin
          // Inner loop finished; advance i and start next outer iteration
          next_state = OUTER_LOOP;
        end
      end

      COMPARE: begin
        // After compare, go to SWAP (may or may not swap)
        next_state = SWAP;
      end

      SWAP: begin
        // After optional swap, advance j or i depending on bounds
        if (j <= (3'd6 - i)) begin
          // Completed this compare/swap; increment j for next pair
          // Note: actual j increment occurs via sequential update style:
          // we'll express via implicit expectation: j+1 used next cycle
        end
        // Determine whether to continue inner loop or move to next outer loop
        if (j < (3'd6 - i)) begin
          // More comparisons in this inner loop
          next_state = INNER_LOOP;
        end else begin
          // Inner loop done for this i: increment i
          next_state = OUTER_LOOP;
        end
      end

      DONE: begin
        // One-cycle done pulse, then go back to IDLE
        next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential updates for loop indices based on state transitions
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i <= 3'd0;
      j <= 3'd0;
    end else begin
      case (state)
        LOAD_DATA: begin
          i <= 3'd0;
          j <= 3'd0;
        end

        OUTER_LOOP: begin
          if (next_state == OUTER_LOOP && i != 3'd0) begin
            // stay; no change
          end else if (next_state == INNER_LOOP) begin
            j <= 3'd0;
          end else if (next_state == DONE) begin
            // no-op
          end
        end

        INNER_LOOP: begin
          // j updated via COMPARE/SWAP states
        end

        COMPARE: begin
          // no index change here
        end

        SWAP: begin
          if (j < (3'd6 - i)) begin
            j <= j + 3'd1;
          end else begin
            j <= 3'd0;
            if (i < 3'd7) begin
              i <= i + 3'd1;
            end
          end
        end

        DONE: begin
          // reset indices (not strictly required)
          i <= 3'd0;
          j <= 3'd0;
        end

        default: begin
        end
      endcase
    end
  end

endmodule