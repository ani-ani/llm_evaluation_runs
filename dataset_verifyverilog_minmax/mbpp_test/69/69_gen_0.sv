module sublist_checker (
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0][7:0] main_list,
  input  [3:0][7:0] sub_list,
  output logic found,
  output logic done
);

  // State machine states
  typedef enum logic { IDLE = 1'b0, RUN = 1'b1 } state_t;
  state_t cs, ns;

  // Control and pipeline signals
  logic [3:0] counter;           // counts 0..7 to assert done after 8 cycles
  logic [2:0] sub_nz_len;        // length of non-zero portion of sub_list
  logic [2:0] main_nz_len;       // length of non-zero portion of main_list
  logic sub_is_empty;            // 1 if sub_list is all zeros (empty)
  logic found_r;                 // registered match result during scan
  logic start_prev;
  logic start_pulse;

  // Compute non-zero lengths
  assign sub_nz_len = (sub_list[3] != 8'h0) ? 3'd4 :
                      (sub_list[2] != 8'h0) ? 3'd3 :
                      (sub_list[1] != 8'h0) ? 3'd2 :
                      (sub_list[0] != 8'h0) ? 3'd1 : 3'd0;

  assign main_nz_len = (main_list[7] != 8'h0) ? 3'd8 :
                       (main_list[6] != 8'h0) ? 3'd7 :
                       (main_list[5] != 8'h0) ? 3'd6 :
                       (main_list[4] != 8'h0) ? 3'd5 :
                       (main_list[3] != 8'h0) ? 3'd4 :
                       (main_list[2] != 8'h0) ? 3'd3 :
                       (main_list[1] != 8'h0) ? 3'd2 :
                       (main_list[0] != 8'h0) ? 3'd1 : 3'd0;

  assign sub_is_empty = (sub_nz_len == 3'd0);

  // Start pulse detection
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) start_prev <= 1'b0;
    else        start_prev <= start;
  end
  assign start_pulse = start && !start_prev;

  // Determine if any 4-element window in main_list matches sub_list (parallel comparators)
  function automatic bit window_matches(input [7:0] a0, a1, a2, a3, b0, b1, b2, b3);
    return (a0 == b0) && (a1 == b1) && (a2 == b2) && (a3 == b3);
  endfunction

  bit [4:0] pos_match; // position matches: indexes 0..4 possible starting positions

  // Compute position matches combinatorially (parallel)
  always_comb begin
    pos_match = 5'b0;
    // Valid start positions: 0..4 (need 4 elements 0..3)
    if (window_matches(main_list[0], main_list[1], main_list[2], main_list[3],
                       sub_list[0], sub_list[1], sub_list[2], sub_list[3]))
      pos_match[0] = 1'b1;
    if (window_matches(main_list[1], main_list[2], main_list[3], main_list[4],
                       sub_list[0], sub_list[1], sub_list[2], sub_list[3]))
      pos_match[1] = 1'b1;
    if (window_matches(main_list[2], main_list[3], main_list[4], main_list[5],
                       sub_list[0], sub_list[1], sub_list[2], sub_list[3]))
      pos_match[2] = 1'b1;
    if (window_matches(main_list[3], main_list[4], main_list[5], main_list[6],
                       sub_list[0], sub_list[1], sub_list[2], sub_list[3]))
      pos_match[3] = 1'b1;
    if (window_matches(main_list[4], main_list[5], main_list[6], main_list[7],
                       sub_list[0], sub_list[1], sub_list[2], sub_list[3]))
      pos_match[4] = 1'b1;
  end

  // Default outputs to avoid latches (combinatorial next-state logic)
  always_comb begin
    ns = cs;
    found = 1'b0; // default: result not found
    done  = 1'b0; // default: not done
    case (cs)
      IDLE: begin
        done = 1'b1; // asserted when not processing
        if (start_pulse) begin
          // Special case: empty sublist always found
          if (sub_is_empty) found = 1'b1;
          ns = RUN;
        end else begin
          found = 1'b0;
        end
      end
      RUN: begin
        // At cycle 8 (counter==7), allow 'done' and 'found' to be updated before IDLE
        if (sub_is_empty) begin
          // If sublist is empty, report found immediately; done remains low until 8 cycles expire
          found = 1'b1;
        end else begin
          // If sublist longer than non-zero part of main list, result is 0
          if (sub_nz_len > main_nz_len) begin
            found = 1'b0;
          end else begin
            // Use position index = counter to pick which parallel result is available
            unique case (counter)
              3'd0: found = pos_match[0];
              3'd1: found = pos_match[1];
              3'd2: found = pos_match[2];
              3'd3: found = pos_match[3];
              3'd4: found = pos_match[4];
              default: found = 1'b0; // unreachable, but keeps tooling happy
            endcase
          end
        end
        // Assert done after 8 cycles in RUN
        done = (counter == 3'd7);
      end
      default: begin
        ns = IDLE;
        found = 1'b0;
        done  = 1'b0;
      end
    endcase
  end

  // State and counter update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cs <= IDLE;
      counter <= 4'd0;
      found_r <= 1'b0;
    end else begin
      cs <= ns;
      if (cs == IDLE && ns == RUN) begin
        // Initialize counter on entry to RUN
        counter <= 4'd0;
        found_r <= 1'b0;
      end else if (cs == RUN) begin
        counter <= counter + 4'd1; // counts 0..7 (one extra to finish cycle-8 timing)
        found_r <= found;          // keep last 'found' for visibility if needed
      end
    end
  end

endmodule
