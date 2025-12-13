module ab_pattern_matcher(
  input        clk,
  input        rst_n,
  input        start,
  input  [7:0] data,
  input        valid,
  output reg   match,
  output reg   done
);

  // State encoding
  localparam IDLE     = 3'd0;
  localparam SEARCH_A = 3'd1;
  localparam SEARCH_B = 3'd2;
  localparam MATCH    = 3'd3;
  localparam NO_MATCH = 3'd4;

  reg [2:0] state, next_state;
  reg       a_found;
  reg       b_seen_after_a;

  // Sequential state and flags update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= IDLE;
      a_found         <= 1'b0;
      b_seen_after_a  <= 1'b0;
      match           <= 1'b0;
      done            <= 1'b0;
    end else begin
      state <= next_state;

      // Default outputs each cycle
      done  <= 1'b0; // done is a pulse

      case (state)
        IDLE: begin
          match          <= 1'b0;
          a_found        <= 1'b0;
          b_seen_after_a <= 1'b0;
        end

        SEARCH_A: begin
          if (valid) begin
            if (data == 8'h61) begin // 'a'
              a_found        <= 1'b1;
              b_seen_after_a <= 1'b0;
            end
          end
        end

        SEARCH_B: begin
          if (valid) begin
            if (data == 8'h62) begin // 'b'
              // Stay in SEARCH_B, valid b extends pattern
              b_seen_after_a <= 1'b1;
            end else begin
              // Any non-'b' after 'a' before end invalidates pattern
              a_found        <= 1'b0;
              b_seen_after_a <= 1'b0;
            end
          end
        end

        MATCH: begin
          match <= 1'b1;
          done  <= 1'b1;
        end

        NO_MATCH: begin
          match <= 1'b0;
          done  <= 1'b1;
        end

        default: begin
          match <= 1'b0;
          done  <= 1'b0;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start)
          next_state = SEARCH_A;
      end

      SEARCH_A: begin
        // Once started, we watch incoming chars while valid is high
        if (valid) begin
          if (data == 8'h61)
            next_state = SEARCH_B;  // Found 'a', now look for one or more 'b'
        end else begin
          // End of string with no valid 'a' followed by 'b'
          next_state = NO_MATCH;
        end
      end

      SEARCH_B: begin
        if (valid) begin
          if (data == 8'h62) begin
            // Keep absorbing 'b's
            next_state = SEARCH_B;
          end else begin
            // Non-'b' encountered after 'a' before end -> fail
            next_state = NO_MATCH;
          end
        end else begin
          // End of string; successful if we've seen at least one 'b' after 'a'
          if (a_found && b_seen_after_a)
            next_state = MATCH;
          else
            next_state = NO_MATCH;
        end
      end

      MATCH: begin
        // After signaling done, wait for next start
        if (start)
          next_state = SEARCH_A;
        else
          next_state = IDLE;
      end

      NO_MATCH: begin
        // After signaling done, wait for next start
        if (start)
          next_state = SEARCH_A;
        else
          next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule