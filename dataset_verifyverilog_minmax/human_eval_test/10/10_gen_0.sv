module shortest_palindrome (
  input clk,
  input rst_n,
  input start,
  input reg [63:0] in_string, // 8 ASCII characters, LSB first
  output reg [127:0] out_palindrome, // 16 ASCII characters, LSB first
  output reg done
);

  parameter CHAR_WIDTH = 8;
  localparam MAX_CHARS = 16'd8;

  typedef enum logic [1:0] { IDLE = 2'd0, CHECKING = 2'd1, APPENDING = 2'd2, DONE = 2'd3 } state_t;
  state_t state;

  reg [4:0] cycle;           // 0..15
  reg [3:0] check_len;       // 8..1
  reg [3:0] check_idx;       // 0..7
  reg [3:0] prefix_rem;      // 0..7 (characters before palindromic suffix)
  reg [3:0] append_cnt;      // 0..7 (characters to append)
  reg is_pal;                // palindrome found flag
  reg [7:0] lsb_byte;        // lsb of out_palindrome for one-hot updates
  integer i;

  function [7:0] get_char;
    input [3:0] index; // 0..7, 0 = first character (LSB of in_string)
    begin
      get_char = in_string[index * CHAR_WIDTH +: CHAR_WIDTH];
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      out_palindrome <= 128'b0;
      cycle <= 5'd0;
      check_len <= 4'd8;
      check_idx <= 4'd0;
      prefix_rem <= 4'd0;
      append_cnt <= 4'd0;
      is_pal <= 1'b0;
      lsb_byte <= 8'b0;
    end else begin
      // Defaults (keep from latching unintentionally)
      lsb_byte <= 8'b0;

      case (state)
        IDLE: begin
          out_palindrome <= 128'b0; // keep zeroed until start
          done <= 1'b0;
          if (start) begin
            state <= CHECKING;
            cycle <= 5'd0;
            check_len <= 4'd8;   // start from longest suffix
            check_idx <= 4'd0;
            is_pal <= 1'b0;
          end
        end

        CHECKING: begin
          // One palindrome-length check per cycle
          if (cycle < check_len) begin
            cycle <= cycle + 5'd1;
          end

          // Compare characters for current check_len
          if (check_idx < (check_len >> 1)) begin
            if (get_char(check_idx) == get_char((check_len - 1) - check_idx)) begin
              check_idx <= check_idx + 4'd1;
              is_pal <= 1'b1; // keep flag high only if all matches so far are true
            end else begin
              is_pal <= 1'b0;
            end
          end

          // Finished checking this length
          if (cycle == (check_len - 1)) begin
            if (is_pal) begin
              // Palindromic suffix found: length = check_len
              prefix_rem <= 4'd8 - check_len;
              append_cnt <= 4'd8 - check_len; // how many chars to append from reversed prefix
              cycle <= 5'd0;
              state <= APPENDING;
              // Initialize output with palindromic suffix, LSB first
              for (i = 0; i < 8; i = i + 1) begin
                if (i < check_len) begin
                  lsb_byte <= get_char(i);
                  out_palindrome <= {8'b0, out_palindrome[127:8]}; // shift left and inject LSB
                end else begin
                  out_palindrome <= {8'b0, out_palindrome[127:8]}; // pad with nulls for remaining bytes
                end
              end
            end else begin
              // Not a palindrome, try shorter length
              if (check_len > 1) begin
                check_len <= check_len - 4'd1;
                check_idx <= 4'd0;
                cycle <= 5'd0;
                is_pal <= 1'b0;
              end else begin
                // No non-trivial palindrome: append full reversed string
                prefix_rem <= 4'd8;
                append_cnt <= 4'd8;
                cycle <= 5'd0;
                state <= APPENDING;
                // Initialize output with 8 nulls, then append in loop below
                for (i = 0; i < 8; i = i + 1) begin
                  out_palindrome <= {8'b0, out_palindrome[127:8]};
                end
              end
            end
          end
        end

        APPENDING: begin
          // Append reversed prefix characters, LSB first
          if (append_cnt > 0) begin
            if (cycle < append_cnt) begin
              // reversed prefix index: 0 -> 7, 1 -> 6, ...
              lsb_byte <= get_char(4'd7 - cycle);
              out_palindrome <= {8'b0, out_palindrome[127:8]};
              cycle <= cycle + 5'd1;
            end
            if (cycle == (append_cnt - 1)) begin
              cycle <= 5'd0;
              state <= DONE;
              done <= 1'b1;
            end
          end else begin
            // palindrome length was 8, nothing to append
            state <= DONE;
            done <= 1'b1;
          end
        end

        DONE: begin
          done <= 1'b1;
          if (!start) begin
            state <= IDLE;
            done <= 1'b0;
            out_palindrome <= 128'b0;
            cycle <= 5'd0;
          end
        end
      endcase
    end
  end

endmodule