module taboo_string_finder(
  input clk,
  input rst_n,
  input start,
  input [1:0] n_taboos,
  input [3:0] taboo0,
  input [3:0] taboo1,
  input [3:0] taboo2,
  input [3:0] taboo3,
  output reg [7:0] result,
  output reg found,
  output reg done
);

  // State encoding
  localparam IDLE       = 3'd0;
  localparam CHECK_TAIL = 3'd1;
  localparam GENERATE   = 3'd2;
  localparam TEST       = 3'd3;
  localparam DONE       = 3'd4;

  reg [2:0] state, next_state;

  // Internal registers
  reg [7:0] candidate;
  reg [3:0] cand_len;            // 0..8
  reg [7:0] best_candidate;
  reg [3:0] best_len;

  reg [3:0] cur_len;             // current tested length
  reg [7:0] cur_mask;            // mask with lower cur_len bits = 1

  reg [1:0] taboo_count;
  reg [3:0] t0, t1, t2, t3;
  reg       has_loop;            // prefix relation detected

  reg       any_taboos;

  // Helper wires
  wire [3:0] c3 = candidate[3:0];
  wire [3:0] c4 = candidate[4:1];
  wire [3:0] c5 = candidate[5:2];
  wire [3:0] c6 = candidate[6:3];
  wire [3:0] c7 = candidate[7:4];

  // Function: check if any taboo is a prefix of any other (length 4 fixed)
  // Here, taboo strings are exactly 4 bits. A prefix relation exists if two
  // taboos are identical, which implies cycle / forbidden loop condition.
  function automatic prefix_loop_detect;
    input [1:0] cnt;
    input [3:0] a0, a1, a2, a3;
    reg match;
    begin
      match = 1'b0;
      if (cnt > 2'd0) begin
        // Use only the first 'cnt' taboos in order: a0..a3
        if (cnt > 2'd1) begin
          if (a0 == a1) match = 1'b1;
        end
        if (cnt > 2'd2) begin
          if (a0 == a2 || a1 == a2) match = 1'b1;
        end
        if (cnt > 2'd3) begin
          if (a0 == a3 || a1 == a3 || a2 == a3) match = 1'b1;
        end
      end
      prefix_loop_detect = match;
    end
  endfunction

  // Function: detect if candidate (with length len) contains any taboo substring
  function automatic has_taboo;
    input [7:0] cand;
    input [3:0] len;
    input [1:0] cnt;
    input [3:0] a0, a1, a2, a3;
    reg hit;
    reg [3:0] w0, w1, w2, w3, w4;
    begin
      hit = 1'b0;

      // Extract all possible 4-bit windows within 8 bits
      w0 = cand[3:0];
      w1 = cand[4:1];
      w2 = cand[5:2];
      w3 = cand[6:3];
      w4 = cand[7:4];

      // Only windows fully inside current length are considered
      // Positions valid if len >= start_index+4
      // start_index = 0..4

      if (cnt > 0) begin
        if (len >= 4  && w0 == a0) hit = 1'b1;
        if (len >= 5  && w1 == a0) hit = 1'b1;
        if (len >= 6  && w2 == a0) hit = 1'b1;
        if (len >= 7  && w3 == a0) hit = 1'b1;
        if (len >= 8  && w4 == a0) hit = 1'b1;
      end
      if (cnt > 1) begin
        if (len >= 4  && w0 == a1) hit = 1'b1;
        if (len >= 5  && w1 == a1) hit = 1'b1;
        if (len >= 6  && w2 == a1) hit = 1'b1;
        if (len >= 7  && w3 == a1) hit = 1'b1;
        if (len >= 8  && w4 == a1) hit = 1'b1;
      end
      if (cnt > 2) begin
        if (len >= 4  && w0 == a2) hit = 1'b1;
        if (len >= 5  && w1 == a2) hit = 1'b1;
        if (len >= 6  && w2 == a2) hit = 1'b1;
        if (len >= 7  && w3 == a2) hit = 1'b1;
        if (len >= 8  && w4 == a2) hit = 1'b1;
      end
      if (cnt > 3) begin
        if (len >= 4  && w0 == a3) hit = 1'b1;
        if (len >= 5  && w1 == a3) hit = 1'b1;
        if (len >= 6  && w2 == a3) hit = 1'b1;
        if (len >= 7  && w3 == a3) hit = 1'b1;
        if (len >= 8  && w4 == a3) hit = 1'b1;
      end

      has_taboo = hit;
    end
  endfunction

  // Precompute if we have any taboos (for infinite case when none)
  always @(*) begin
    any_taboos = (n_taboos != 2'd0);
  end

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      candidate      <= 8'd0;
      cand_len       <= 4'd0;
      best_candidate <= 8'd0;
      best_len       <= 4'd0;
      cur_len        <= 4'd0;
      cur_mask       <= 8'd0;
      taboo_count    <= 2'd0;
      t0             <= 4'd0;
      t1             <= 4'd0;
      t2             <= 4'd0;
      t3             <= 4'd0;
      has_loop       <= 1'b0;
      result         <= 8'd0;
      found          <= 1'b0;
      done           <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done   <= 1'b0;
          found  <= 1'b0;
          result <= 8'd0;
          if (start) begin
            // Latch inputs
            taboo_count <= n_taboos;
            t0 <= taboo0;
            t1 <= taboo1;
            t2 <= taboo2;
            t3 <= taboo3;

            // Reset search variables
            candidate      <= 8'd0;
            cand_len       <= 4'd1;    // start from length 1
            best_candidate <= 8'd0;
            best_len       <= 4'd0;
            cur_len        <= 4'd0;
            cur_mask       <= 8'd0;
            has_loop       <= 1'b0;
          end
        end

        CHECK_TAIL: begin
          // Determine if infinite length possible:
          // 1) If no taboos: infinite.
          // 2) If duplicated taboo (our prefix loop proxy): infinite.
          has_loop <= (!any_taboos) || prefix_loop_detect(taboo_count, t0, t1, t2, t3);
        end

        GENERATE: begin
          // If infinite loop detected, nothing to generate
          if (has_loop) begin
            // nothing changed here
          end else begin
            // Generate next candidate string.
            // We enumerate by increasing length; within same length, lexicographic ascending.
            if (cand_len == 0) begin
              cand_len  <= 4'd1;
              candidate <= 8'd0;
            end else if (cand_len <= 4'd8) begin
              // Determine mask for current length
              case (cand_len)
                4'd1: cur_mask <= 8'b0000_0001;
                4'd2: cur_mask <= 8'b0000_0011;
                4'd3: cur_mask <= 8'b0000_0111;
                4'd4: cur_mask <= 8'b0000_1111;
                4'd5: cur_mask <= 8'b0001_1111;
                4'd6: cur_mask <= 8'b0011_1111;
                4'd7: cur_mask <= 8'b0111_1111;
                default: cur_mask <= 8'b1111_1111;
              endcase

              // Next candidate bits within current length
              if (((candidate + 1'b1) & cur_mask) == 0) begin
                // Exhausted current length, move to next length
                cand_len  <= cand_len + 1'b1;
                candidate <= 8'd0;
              end else begin
                candidate <= (candidate + 1'b1) & cur_mask;
              end
            end
          end
        end

        TEST: begin
          if (!has_loop) begin
            // Test current candidate if within length limit
            if (cand_len != 0 && cand_len <= 4'd8) begin
              if (!has_taboo(candidate, cand_len, taboo_count, t0, t1, t2, t3)) begin
                // Valid candidate: update best if longer, or same length and lexicographically smaller
                if (cand_len > best_len) begin
                  best_len       <= cand_len;
                  best_candidate <= candidate;
                end else if (cand_len == best_len && cand_len != 0) begin
                  // Lexicographic: 0<1; lower numeric value in LSB-aligned representation
                  if (candidate < best_candidate) begin
                    best_candidate <= candidate;
                  end
                end
              end
            end
          end
        end

        DONE: begin
          done <= 1'b1;
          if (has_loop) begin
            found  <= 1'b0;   // infinite length possible
            result <= 8'd0;   // undefined per spec
          end else begin
            found  <= 1'b1;
            result <= best_candidate; // LSB-aligned
          end
        end

        default: begin
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = CHECK_TAIL;
        end
      end

      CHECK_TAIL: begin
        next_state = GENERATE;
      end

      GENERATE: begin
        if (has_loop) begin
          // If infinite, directly go DONE
          next_state = DONE;
        end else begin
          // If all lengths (1..8) tried and wrapped beyond 8 -> done
          if (cand_len > 4'd8) begin
            next_state = DONE;
          end else begin
            next_state = TEST;
          end
        end
      end

      TEST: begin
        if (has_loop) begin
          next_state = DONE;
        end else if (cand_len > 4'd8) begin
          next_state = DONE;
        end else begin
          next_state = GENERATE;
        end
      end

      DONE: begin
        // Wait until start deasserted, then return IDLE
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule