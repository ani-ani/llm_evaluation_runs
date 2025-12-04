module numeric_string_sorter (
  input  clk,
  input  rst_n,
  input  start,
  input  logic [11:0] numbers [7:0],
  output logic [11:0] sorted [7:0],
  output logic done
);

  localparam N = 8;  // Number of elements

  typedef enum logic [1:0] { IDLE = 2'b00, COMPARE = 2'b01, SWAP = 2'b10, DONE = 2'b11 } fsm_state_t;
  fsm_state_t state, next_state;

  logic [11:0] data [7:0];  // Working array for sorting
  logic [11:0] data_next [7:0];
  logic [2:0] i, i_next;    // Comparison index (0..6)
  logic swapped, swapped_next;
  logic start_r1, start_r2; // Synchronized start pulse
  logic start_shot;         // One-cycle start detection

  integer k;

  // Initialize sorted output (outside clocked always block, synth-friendly)
  assign sorted = data;

  // Synchronize start and generate single-cycle start_shot
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_r1 <= 1'b0;
      start_r2 <= 1'b0;
    end else begin
      start_r1 <= start;
      start_r2 <= start_r1;
    end
  end
  assign start_shot = start_r1 && ~start_r2;

  // Next-state logic (combinational)
  always_comb begin
    // Defaults
    next_state = state;
    i_next     = i;
    swapped_next = swapped;

    // Copy working array by default
    for (k = 0; k < N; k++) data_next[k] = data[k];

    case (state)
      IDLE: begin
        // Start received: load input numbers and begin sorting
        if (start_shot) begin
          for (k = 0; k < N; k++) data_next[k] = numbers[k];
          i_next = 3'd0;
          swapped_next = 1'b0;
          next_state = COMPARE;
        end
      end

      COMPARE: begin
        if (i < (N - 1)) begin
          if ($signed(data[i]) > $signed(data[i + 1])) begin
            // Swap the pair
            data_next[i]     = data[i + 1];
            data_next[i + 1] = data[i];
            swapped_next = 1'b1;
            next_state = SWAP;
          end else begin
            // No swap: move to next pair
            i_next = i + 1;
          end
        end else begin
          // Reached the end of a pass
          if (swapped) begin
            // Another pass needed
            i_next = 3'd0;
            next_state = COMPARE;
          end else begin
            // No swaps: done
            next_state = DONE;
          end
        end
      end

      SWAP: begin
        // Proceed to next pair after a swap
        if (i < (N - 1)) begin
          i_next = i + 1;
        end else begin
          // End of pass: check if another is needed
          if (swapped) begin
            i_next = 3'd0;
          end else begin
            next_state = DONE;
          end
        end
        next_state = (i < (N - 1)) ? COMPARE : (swapped ? COMPARE : DONE);
      end

      DONE: begin
        // Wait for a new start or remain in DONE until reset/next start_shot
        if (start_shot) begin
          for (k = 0; k < N; k++) data_next[k] = numbers[k];
          i_next = 3'd0;
          swapped_next = 1'b0;
          next_state = COMPARE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

  // State and data registers (sequential, non-blocking assignments)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i     <= 3'd0;
      swapped <= 1'b0;
      for (k = 0; k < N; k++) data[k] <= 12'h000;
      done   <= 1'b0;
    end else begin
      state   <= next_state;
      i       <= i_next;
      swapped <= swapped_next;
      for (k = 0; k < N; k++) data[k] <= data_next[k];
      done    <= (next_state == DONE);
    end
  end

endmodule
