module shortest_palindrome #(
  parameter CHAR_WIDTH = 8
) (
  input  wire                     clk,
  input  wire                     rst_n,
  input  wire                     start,
  input  wire [63:0]              in_string,   // 8 ASCII chars, LSB-first
  output reg  [127:0]             out_palindrome, // 16 ASCII chars, LSB-first
  output reg                      done
);

  // FSM States
  localparam IDLE     = 2'b00;
  localparam CHECKING = 2'b01;
  localparam APPENDING= 2'b10;
  localparam DONE_ST  = 2'b11;

  reg [1:0]  state, next_state;

  // Internal registers
  reg [63:0] in_reg;              // Latched input string
  reg [3:0]  start_idx;           // Current candidate start index for palindromic suffix
  reg [3:0]  left_idx;            // Left index for palindrome check
  reg [3:0]  right_idx;           // Right index (fixed at 7 for suffix)
  reg        checking_active;     // Indicates ongoing comparison for current candidate
  reg        pal_ok;              // Palindrome check result for current candidate
  reg [3:0]  best_start_idx;      // Start index of longest palindromic suffix found

  // APPENDING control
  reg [3:0]  append_idx;          // Index for copying the palindrome suffix
  reg [3:0]  prefix_idx;          // Index for appending reversed prefix

  // Output buffer as bytes for clarity
  reg [CHAR_WIDTH-1:0] out_bytes [0:15];

  integer i;

  // Helper: extract character at index idx from in_reg (idx 0 = LSB byte)
  function [CHAR_WIDTH-1:0] get_char;
    input [63:0] data;
    input [3:0]  idx;
    begin
      get_char = data[CHAR_WIDTH*idx +: CHAR_WIDTH];
    end
  endfunction

  // Pack out_bytes into out_palindrome
  always @(*) begin
    out_palindrome = 128'b0;
    for (i = 0; i < 16; i = i + 1) begin
      out_palindrome[CHAR_WIDTH*i +: CHAR_WIDTH] = out_bytes[i];
    end
  end

  // FSM sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= IDLE;
      in_reg          <= 64'b0;
      start_idx       <= 4'd0;
      left_idx        <= 4'd0;
      right_idx       <= 4'd7;
      checking_active <= 1'b0;
      pal_ok          <= 1'b0;
      best_start_idx  <= 4'd7; // default: at least last char is palindrome
      append_idx      <= 4'd0;
      prefix_idx      <= 4'd0;
      done            <= 1'b0;
      for (i = 0; i < 16; i = i + 1) begin
        out_bytes[i] <= {CHAR_WIDTH{1'b0}};
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Latch input string and initialize for palindrome search
            in_reg          <= in_string;
            start_idx       <= 4'd0;
            right_idx       <= 4'd7;
            // Begin checking from longest possible suffix (0..7)
            left_idx        <= 4'd0;
            pal_ok          <= 1'b1;
            checking_active <= 1'b1;
            best_start_idx  <= 4'd7; // minimal palindrome suffix is last character
            // Clear output buffer
            for (i = 0; i < 16; i = i + 1) begin
              out_bytes[i] <= {CHAR_WIDTH{1'b0}};
            end
          end
        end

        CHECKING: begin
          if (checking_active) begin
            // Compare characters at current left_idx and right_idx
            if (get_char(in_reg, left_idx) != get_char(in_reg, right_idx)) begin
              pal_ok          <= 1'b0;
              checking_active <= 1'b0; // mismatch: stop checking this candidate
            end else begin
              // Move inward
              if (left_idx + 1 >= right_idx) begin
                // Palindrome confirmed for this start_idx..7
                pal_ok          <= pal_ok; // remains 1
                checking_active <= 1'b0;
              end else begin
                left_idx <= left_idx + 1;
              end
            end
          end else begin
            // Completed check for current candidate start_idx
            if (pal_ok) begin
              // Found a (possibly longest so far) palindromic suffix
              best_start_idx <= start_idx;
              // We intentionally continue to next candidates only if longer exists.
              // But since we started from smallest index and move upward,
              // the first pal_ok we hit is the longest.
              // So we could directly finish scanning here by jumping start_idx to 8.
              start_idx <= 4'd8; // force end of search
            end else begin
              // Try next candidate start index if any
              if (start_idx < 4'd7) begin
                start_idx       <= start_idx + 1;
                left_idx        <= start_idx + 1;
                pal_ok          <= 1'b1;
                checking_active <= 1'b1;
              end else begin
                // No more candidates
                start_idx <= 4'd8; // mark search done
              end
            end
          end
        end

        APPENDING: begin
          // Two-phase build:
          // 1) Copy palindromic suffix [best_start_idx..7] into out_bytes[0..]
          // 2) Append reversed prefix [best_start_idx-1..0]

          if (append_idx <= 4'd7) begin
            // Phase 1: copy suffix, using only valid indexes
            if (best_start_idx + append_idx <= 7) begin
              out_bytes[append_idx] <= get_char(in_reg, best_start_idx + append_idx);
              append_idx            <= append_idx + 1;
            end else begin
              // Move to prefix phase init
              prefix_idx <= (best_start_idx == 0) ? 4'd15 : (best_start_idx - 1);
              append_idx <= 4'd8; // marker that suffix phase done
            end
          end else begin
            // Phase 2: append reversed prefix into subsequent positions
            if (best_start_idx > 0) begin
              // Determine next output index after suffix
              // suffix_len = 8 - best_start_idx
              // prefix chars go starting at suffix_len
              // We compute on the fly using temporary variables
              integer suffix_len;
              suffix_len = 8 - best_start_idx;

              if (prefix_idx < 4'd8 && prefix_idx >= 0) begin
                // Use prefix_idx as input index, map to output position
                out_bytes[suffix_len + (best_start_idx - 1 - prefix_idx)] <= get_char(in_reg, prefix_idx);
                if (prefix_idx == 0) begin
                  // Done appending prefix
                  prefix_idx <= 4'd15; // mark done
                end else begin
                  prefix_idx <= prefix_idx - 1;
                end
              end
            end
          end
        end

        DONE_ST: begin
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // FSM next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = CHECKING;
      end

      CHECKING: begin
        // Transition when current candidate search is fully done
        if (!checking_active) begin
          if (pal_ok) begin
            // Longest palindromic suffix found
            next_state = APPENDING;
          end else if (start_idx >= 4'd7) begin
            // Tried all candidates, use default best_start_idx (likely 7)
            next_state = APPENDING;
          end else begin
            // Will start next candidate in sequential block; stay in CHECKING
            next_state = CHECKING;
          end
        end else begin
          next_state = CHECKING;
        end
      end

      APPENDING: begin
        // Decide when appending is complete:
        // Completion condition: suffix and prefix placement finished.
        // For simplicity, detect when prefix_idx has been marked as 15 after finishing.
        if ((append_idx > 4'd7) && (prefix_idx == 4'd15 || best_start_idx == 0)) begin
          next_state = DONE_ST;
        end else begin
          next_state = APPENDING;
        end
      end

      DONE_ST: begin
        // Stay done until next start pulse (simple behavior)
        if (!start)
          next_state = IDLE;
        else
          next_state = DONE_ST;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule
