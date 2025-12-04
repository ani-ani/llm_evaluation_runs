module string_compressor(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // start computation
  output reg [15:0] result, // number of valid strings (max 46656)
  output reg done // high when computation complete
);

  // Configurable n (2..6). For different tests, change N and recompile.
  parameter N = 6;                // string length (1..6). For 2..6 per spec.
  localparam BASE = 6;            // base per character
  localparam COUNTER_WIDTH = 16;  // enough for 6^6 = 46656

  // State encoding
  localparam S_IDLE  = 2'b00;
  localparam S_REDUCE = 2'b01;
  localparam S_NEXT   = 2'b10;
  localparam S_DONE   = 2'b11;

  // Storage for current string under test (3 bits per char, max 6 chars)
  reg [17:0] curr_str;     // packed 18-bit storage (3*N <= 18)
  reg [2:0] curr_len;      // dynamic current length (1..N)
  reg [15:0] counter;      // counts from 0 to 6^N-1
  reg [15:0] count_max;
  reg [15:0] match_count;  // number of strings compressed to 'a'
  reg [1:0] state;

  // Current base-6 digit being expanded (0..5)
  reg [2:0] digit;
  integer i;

  // Map digit (0..5) to 3-bit char code: 0->0, 1->1, 2->2, 3->3, 4->4, 5->5
  function [2:0] digit_to_code;
    input [2:0] d;
    begin
      // Safe default; per spec, d is 0..5
      digit_to_code = d;
    end
  endfunction

  // ROM-based 36 rules: 2-char (6b) -> 1-char (3b)
  // Implemented as casex; 36 rules using only a..f (codes 0..5)
  function [2:0] apply_rule;
    input [5:0] pair; // {c1, c2}, each 3 bits valid 0..5
    reg [2:0] c1, c2, out;
    begin
      c1 = pair[5:3];
      c2 = pair[2:0];
      // default: no rule matches
      out = 3'bxxx;
      // 36 rules: 2-char -> 1-char
      casex ({c1, c2})
        // aa->a
        6'b000000: out = 3'b000; // aa->a
        6'b000001: out = 3'b001; // ab->b
        6'b000010: out = 3'b010; // ac->c
        6'b000011: out = 3'b011; // ad->d
        6'b000100: out = 3'b100; // ae->e
        6'b000101: out = 3'b101; // af->f

        6'b010000: out = 3'b001; // ba->b
        6'b010001: out = 3'b000; // bb->a
        6'b010010: out = 3'b010; // bc->c
        6'b010011: out = 3'b011; // bd->d
        6'b010100: out = 3'b100; // be->e
        6'b010101: out = 3'b101; // bf->f

        6'b100000: out = 3'b010; // ca->c
        6'b100001: out = 3'b010; // cb->c
        6'b100010: out = 3'b000; // cc->a
        6'b100011: out = 3'b011; // cd->d
        6'b100100: out = 3'b100; // ce->e
        6'b100101: out = 3'b101; // cf->f

        6'b110000: out = 3'b011; // da->d
        6'b110001: out = 3'b011; // db->d
        6'b110010: out = 3'b011; // dc->d
        6'b110011: out = 3'b000; // dd->a
        6'b110100: out = 3'b100; // de->e
        6'b110101: out = 3'b101; // df->f

        6'b000001, 6'b001000: out = 3'b000; // ab->a, ea->a
        6'b001001: out = 3'b000; // eb->a
        6'b001010: out = 3'b000; // ec->a
        6'b001011: out = 3'b000; // ed->a
        6'b001100: out = 3'b000; // ee->a
        6'b001101: out = 3'b000; // ef->a

        6'b101000: out = 3'b000; // fa->a
        6'b101001: out = 3'b000; // fb->a
        6'b101010: out = 3'b000; // fc->a
        6'b101011: out = 3'b000; // fd->a
        6'b101100: out = 3'b000; // fe->a
        6'b101101: out = 3'b000; // ff->a

        default: out = 3'bxxx;
      endcase
      apply_rule = out;
    end
  endfunction

  // Compute 6^N at elaboration time (for N<=6)
  function [15:0] pow6;
    input [31:0] n;
    integer k;
    reg [31:0] res;
    begin
      res = 1;
      for (k = 0; k < n; k = k + 1) begin
        res = res * 6;
      end
      pow6 = res[15:0];
    end
  endfunction

  initial begin
    count_max = pow6(N);
  end

  // Main FSM
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 16'h0;
      done <= 1'b0;
      counter <= 16'h0;
      match_count <= 16'h0;
      curr_str <= 18'h0;
      curr_len <= 3'd0;
      state <= S_IDLE;
      digit <= 3'd0;
    end else begin
      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            counter <= 16'h0;
            match_count <= 16'h0;
            state <= S_NEXT;
          end else begin
            state <= S_IDLE;
          end
        end

        S_NEXT: begin
          // Convert counter to base-6 string of length N
          curr_str <= 18'h0;
          curr_len <= N;
          for (i = 0; i < N; i = i + 1) begin
            digit = counter % BASE; // 0..5
            // Place digit at position i (3 bits per char)
            curr_str[i*3 +: 3] = digit_to_code(digit);
            counter = counter / BASE;
          end
          // Reset counter for next use
          counter = (counter == count_max - 1) ? 16'h0 : (counter + 1);
          // Now reduce this string
          state <= S_REDUCE;
        end

        S_REDUCE: begin
          if (curr_len == 3'd1) begin
            // Reached length 1: check if result is 'a' (code 0)
            if (curr_str[2:0] == 3'b000) begin
              match_count <= match_count + 1;
            end
            // Decide whether to move to next string or finish
            if (counter == count_max - 1) begin
              result <= match_count;
              done <= 1'b1;
              state <= S_DONE;
            end else begin
              state <= S_NEXT;
            end
          end else begin
            // Try to find a reducible pair in a single cycle
            // Scan positions 0..curr_len-2 for a match
            if (|curr_str[17:0]) begin
              // Build a flag to detect any match; also update string if a match is found
              reg [5:0] match_pos; // one-hot 6 bits (max N=6, positions 0..5 valid for 2 chars)
              reg [17:0] new_str;
              reg [2:0] new_len;
              reg [5:0] pair_key;
              reg [2:0] rule_out;
              reg found;
              integer j;

              match_pos = 6'b0;
              found = 1'b0;
              new_str = curr_str;
              new_len = curr_len;

              for (j = 0; j < 6; j = j + 1) begin
                if (!found && (j < (curr_len - 1))) begin
                  // Extract pair at position j
                  pair_key = {curr_str[j*3 +: 3], curr_str[(j+1)*3 +: 3]};
                  rule_out = apply_rule(pair_key);
                  if (^rule_out !== 1'bx) begin
                    // Replace pair with rule_out, shift left following chars, and decrement length
                    new_str[j*3 +: 3] = rule_out;
                    // Shift subsequent characters left by 3 bits (1 char)
                    new_str[(j+1)*3 +: 15] = curr_str[(j+2)*3 +: 15];
                    new_len = curr_len - 1;
                    found = 1'b1;
                  end
                end
              end

              if (found) begin
                curr_str <= new_str;
                curr_len <= new_len;
                // Remain in S_REDUCE; one reduction per cycle
                state <= S_REDUCE;
              end else begin
                // No rule applies; string is stuck -> move on
                if (counter == count_max - 1) begin
                  result <= match_count;
                  done <= 1'b1;
                  state <= S_DONE;
                end else begin
                  state <= S_NEXT;
                end
              end
            end else begin
              // Should not happen; just move on
              if (counter == count_max - 1) begin
                result <= match_count;
                done <= 1'b1;
                state <= S_DONE;
              end else begin
                state <= S_NEXT;
              end
            end
          end
        end

        S_DONE: begin
          // Stay here until a new start
          done <= 1'b1;
          if (start) begin
            // Restart a new computation
            counter <= 16'h0;
            match_count <= 16'h0;
            state <= S_NEXT;
          end else begin
            state <= S_DONE;
          end
        end

        default: begin
          state <= S_IDLE;
        end
      endcase
    end
  end

endmodule
