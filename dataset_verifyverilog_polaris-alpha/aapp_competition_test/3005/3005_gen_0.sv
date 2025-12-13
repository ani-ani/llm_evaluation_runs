module string_factoring_weight(
  input clk,
  input rst_n,
  input start,
  input [3:0] length,
  input [7:0] chars [15:0],
  output reg [4:0] weight,
  output reg done
);

  // State encoding
  localparam S_IDLE      = 3'd0;
  localparam S_INIT      = 3'd1;
  localparam S_TRY_L     = 3'd2;
  localparam S_CHECK_PAIR= 3'd3;
  localparam S_COUNT_W   = 3'd4;
  localparam S_NEXT_L    = 3'd5;
  localparam S_DONE      = 3'd6;

  reg [2:0] state, next_state;

  // Registers
  reg [3:0] L;                // current candidate substring length
  reg [3:0] i;                // index for pair checking / scanning
  reg match_flag;             // holds comparison result for current pair
  reg any_factoring;          // indicates any valid factoring found

  reg [4:0] min_weight;       // track minimum weight
  reg fact_valid_for_L;       // flag if current L has at least one irreducible factoring

  // For weight counting (distinct character count)
  reg [25:0] char_seen;       // bitmap for 'A'..'Z'
  reg [4:0] current_weight;   // current factoring weight

  // Utility wires
  wire [3:0] half_len = {1'b0, length[3:1]}; // length/2 (integer division)

  // Compare substring chars[i .. i+L-1] with chars[i+L .. i+2L-1]
  // Implemented sequentially inside S_CHECK_PAIR via match_flag & i.

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT;
      end

      S_INIT: begin
        // move to trying first L if possible, else done
        if (length < 2)
          next_state = S_DONE;
        else
          next_state = S_TRY_L;
      end

      S_TRY_L: begin
        // If L exceeds half_len, we're done searching
        if (L == 0 || L > half_len)
          next_state = S_DONE;
        else begin
          // Begin checking pairs for this L
          next_state = S_CHECK_PAIR;
        end
      end

      S_CHECK_PAIR: begin
        // We iterate i inside this state.
        // When scan for this L completes (i no longer allows another full pair),
        // either we go to weight count (if found any pair) or NEXT_L.
        if (i + (L << 1) > length) begin
          if (fact_valid_for_L)
            next_state = S_COUNT_W;
          else
            next_state = S_NEXT_L;
        end
      end

      S_COUNT_W: begin
        // Count unique chars for entire string; when completed, go NEXT_L
        if (i == length)
          next_state = S_NEXT_L;
      end

      S_NEXT_L: begin
        // Increment L and continue search or finish
        if (L + 1 > half_len)
          next_state = S_DONE;
        else
          next_state = S_TRY_L;
      end

      S_DONE: begin
        // Wait here until next start
        if (!start)
          next_state = S_IDLE;
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  integer k;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= S_IDLE;
      done           <= 1'b0;
      weight         <= 5'd0;
      min_weight     <= 5'd31; // max 16, so 31 is safe sentinel
      L              <= 4'd0;
      i              <= 4'd0;
      match_flag     <= 1'b0;
      any_factoring  <= 1'b0;
      fact_valid_for_L <= 1'b0;
      char_seen      <= 26'd0;
      current_weight <= 5'd0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done           <= 1'b0;
          if (start) begin
            // prepare in INIT
            min_weight     <= 5'd31;
            any_factoring  <= 1'b0;
          end
        end

        S_INIT: begin
          // Initialize for first L
          if (length < 2) begin
            // no possible factorings, weight = length (unique chars upper bound)
            // but spec: weight of maximal factoring; with no repetition, weight = number of unique chars
            // We compute it directly here sequentially:
            char_seen      <= 26'd0;
            current_weight <= 5'd0;
            i              <= 4'd0;
          end else begin
            L <= 4'd1;
            i <= 4'd0;
            fact_valid_for_L <= 1'b0;
          end
        end

        // For length < 2, we fall through to DONE via S_DONE (handled in next_state)

        S_TRY_L: begin
          // Start scanning for this L
          i <= 4'd0;
          fact_valid_for_L <= 1'b0;
        end

        S_CHECK_PAIR: begin
          // If still room for pair, compare next character pair step-by-step
          if (i + (L << 1) <= length) begin
            // Compare substrings of length L starting at i and i+L
            match_flag <= 1'b1;
            for (k = 0; k < 16; k = k + 1) begin
              // loop bounded, but only first L used via conditional
            end
            // explicit compare loop
            for (k = 0; k < 16; k = k + 1) begin
              if (k < L) begin
                if (chars[i + k] != chars[i + L + k]) begin
                  match_flag <= 1'b0;
                end
              end
            end
            if (match_flag) begin
              fact_valid_for_L <= 1'b1;
            end
            // advance i by 1 for next starting position
            i <= i + 1'b1;
          end
          // when no room for pair, transitions handled in next_state
        end

        S_COUNT_W: begin
          // Count unique characters across full string using char_seen bitmap
          if (i == 0) begin
            char_seen      <= 26'd0;
            current_weight <= 5'd0;
          end

          if (i < length) begin
            // assume uppercase letters A-Z (0x41-0x5A)
            if (chars[i] >= 8'h41 && chars[i] <= 8'h5A) begin
              if (!char_seen[chars[i] - 8'h41]) begin
                char_seen[chars[i] - 8'h41] <= 1'b1;
                current_weight <= current_weight + 1'b1;
              end
            end
            i <= i + 1'b1;
          end else begin
            // finished counting; update min_weight
            if (current_weight < min_weight) begin
              min_weight <= current_weight;
              any_factoring <= 1'b1;
            end
          end
        end

        S_NEXT_L: begin
          // Try next L
          L <= L + 1'b1;
          i <= 4'd0;
          fact_valid_for_L <= 1'b0;
        end

        S_DONE: begin
          // If any factoring found, weight = min_weight, else
          // weight = unique characters of entire string.
          if (!done) begin
            if (length == 0) begin
              weight <= 5'd0;
            end else if (!any_factoring) begin
              // compute unique chars once when entering DONE with no factoring
              // simple combinational-like loop using chars (since length <=16)
              char_seen      <= 26'd0;
              current_weight <= 5'd0;
              for (k = 0; k < 16; k = k + 1) begin
                if (k < length) begin
                  if (chars[k] >= 8'h41 && chars[k] <= 8'h5A) begin
                    if (!char_seen[chars[k] - 8'h41]) begin
                      char_seen[chars[k] - 8'h41] <= 1'b1;
                      current_weight <= current_weight + 1'b1;
                    end
                  end
                end
              end
              weight <= current_weight;
            end else begin
              weight <= min_weight;
            end
            done <= 1'b1;
          end
        end

        default: ;
      endcase
    end
  end

endmodule