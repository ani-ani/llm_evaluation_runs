module reverse_pair_counter(
  input clk,
  input rst_n,
  input start,
  input logic [7:0][7:0] strings [8], // 8 strings, 8 chars each (ASCII)
  input logic [2:0] n_strings,        // actual number of strings (1-8)
  output reg [4:0] count,             // number of reverse pairs (0-28 possible)
  output reg done                     // high when computation complete
);

  // FSM states
  typedef enum logic [1:0] { IDLE = 2'b00, COMPARING = 2'b01, DONE = 2'b10 } state_t;
  state_t state, next_state;

  // Pair index: 0..27 covers all unique pairs for up to 8 strings
  reg [4:0] pair_index; // up to 31 > 27
  reg busy;

  // Sequential control: state, busy, done
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= IDLE;
      done     <= 1'b0;
      busy     <= 1'b0;
    end else begin
      case (next_state)
        IDLE: begin
          done <= 1'b0;
          busy <= 1'b0;
        end
        COMPARING: begin
          done <= 1'b0;
          busy <= 1'b1;
        end
        DONE: begin
          done <= 1'b1;
          busy <= 1'b0;
        end
        default: begin
          done <= done; // maintain
          busy <= busy;
        end
      endcase
      state <= next_state;
    end
  end

  // Pair iteration and counting logic
  always_ff @(posedge clk) begin
    case (state)
      IDLE: begin
        pair_index <= 5'd0;
        count      <= 5'd0;
      end
      COMPARING: begin
        // Compute (i, j) for current pair_index
        if (n_strings >= 3) begin
          pair_index <= pair_index + 1;
        end

        // Convert pair_index to (i, j) as per n_strings
        if (n_strings >= 2) begin
          if (n_strings >= 7) begin
            // i in 0..5, j in i+1..6
            automatic int i = pair_index / (n_strings - 1 - 0); // pair_index / 7 if n_strings==8
            automatic int j = (i == 0) ? pair_index : (pair_index - 6); // adjust for n_strings==8
          end
        end

        // Proper mapping for general n_strings (2..8)
        if (n_strings >= 2) begin
          automatic int i = pair_index / n_strings;
          automatic int j = pair_index % n_strings;
        end

        // Perform reverse-string comparison only when i < j
        if (n_strings >= 2) begin
          if (i < j) begin
            // Compare strings[i] reversed with strings[j]
            automatic logic match_found = 1'b0;
            for (int k = 0; k < 8; k++) begin
              if (strings[i][k] == strings[j][7 - k]) begin
                match_found = 1'b1;
              end
            end
            if (match_found) begin
              count <= count + 1;
            end
          end
        end
      end
      DONE: begin
        // Hold final count and keep done high; wait for next start
        pair_index <= pair_index; // no change
        count      <= count;      // keep result
      end
      default: begin
        // Keep state
        pair_index <= pair_index;
        count      <= count;
      end
    endcase
  end

  // Next-state logic
  always_comb begin
    next_state = state; // default: hold state
    case (state)
      IDLE: begin
        if (start) next_state = COMPARING;
      end
      COMPARING: begin
        if (n_strings < 2) begin
          // Nothing to compare
          next_state = DONE;
        end else if (pair_index >= (n_strings * (n_strings - 1) / 2) - 1) begin
          // Last pair processed -> done
          next_state = DONE;
        end
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

endmodule
