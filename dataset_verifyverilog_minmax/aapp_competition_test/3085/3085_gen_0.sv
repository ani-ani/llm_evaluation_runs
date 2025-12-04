module bracket_converter(
  input clk,
  input rst_n,
  input start,
  input [7:0] input_str,
  output reg [511:0] output_buf,
  output reg [5:0] output_len,
  output reg done
);

  // Internal state
  typedef enum logic [1:0] {
    IDLE   = 2'b00,
    ACTIVE = 2'b01,
    DONE   = 2'b10
  } state_t;

  state_t state;
  logic [2:0] i;            // character index (0..7)
  logic [2:0] sp;           // stack pointer
  logic [2:0] stack [0:3];  // depth up to 4
  logic [5:0] out_ptr;      // next write position (bytes)
  logic [5:0] out_bytes;    // total bytes written
  logic [511:0] out_buf_reg; // internal copy of output buffer

  // Signals for header generation
  logic do_write_header;
  logic [5:0] write_start_abs, write_end_abs;

  // Temporary combinational variables
  logic [511:0] new_buf;
  logic [5:0] new_ptr;
  logic [5:0] new_bytes;

  // Header construction helpers
  logic [7:0] header_bytes[0:5];
  logic [3:0] header_len;
  logic [3:0] start_digits, end_digits;

  // Combinational block to compute next buffer values
  always_comb begin
    // Default: keep old values
    new_buf = out_buf_reg;
    new_ptr = out_ptr;
    new_bytes = out_bytes;

    if (do_write_header) begin
      // Determine number of digits for start
      if (write_start_abs < 10) begin
        start_digits = 1;
        header_bytes[0] = 8'h30 + write_start_abs[3:0];
      end else begin
        start_digits = 2;
        header_bytes[0] = 8'h30 + (write_start_abs / 10);
        header_bytes[1] = 8'h30 + (write_start_abs % 10);
      end

      // Comma separator
      header_bytes[start_digits] = 8'h2C;

      // Determine number of digits for end
      if (write_end_abs < 10) begin
        end_digits = 1;
        header_bytes[start_digits+1] = 8'h30 + write_end_abs[3:0];
      end else begin
        end_digits = 2;
        header_bytes[start_digits+1] = 8'h30 + (write_end_abs / 10);
        header_bytes[start_digits+2] = 8'h30 + (write_end_abs % 10);
      end

      // Colon terminator
      header_bytes[start_digits+1+end_digits] = 8'h3A;

      // Total header length
      header_len = start_digits + 1 + end_digits + 1; // +1 for comma, +1 for colon

      // Write the header into the buffer
      for (int k = 0; k < header_len; k++) begin
        new_buf[(out_ptr + k)*8 +: 8] = header_bytes[k];
      end

      // Update pointers
      new_ptr = out_ptr + header_len;
      new_bytes = out_bytes + header_len;
    end
  end

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      i          <= 3'b0;
      sp         <= 3'b0;
      out_ptr    <= 6'b0;
      out_bytes  <= 6'b0;
      out_buf_reg<= 512'b0;
      output_buf <= 512'b0;
      output_len <= 6'b0;
      done       <= 1'b0;
      do_write_header <= 1'b0;
      write_start_abs <= 6'b0;
      write_end_abs   <= 6'b0;
    end else begin
      // Update outputs with the newly computed values
      out_buf_reg <= new_buf;
      out_ptr     <= new_ptr;
      out_bytes   <= new_bytes;
      output_buf  <= new_buf;
      output_len  <= new_bytes;
      done        <= (state == DONE);
      do_write_header <= 1'b0; // default, will be asserted when needed

      // State machine
      case (state)
        IDLE: begin
          if (start) begin
            // Reset internal state and start processing
            i          <= 3'b0;
            sp         <= 3'b0;
            out_ptr    <= 6'b0;
            out_bytes  <= 6'b0;
            out_buf_reg<= 512'b0;
            state      <= ACTIVE;
          end
        end

        ACTIVE: begin
          if (i < 3'b8) begin
            logic char;
            char = input_str[i];
            if (char) begin
              // Opening parenthesis '(' -> push index
              stack[sp] <= i;
              sp <= sp + 1;
            end else begin
              // Closing parenthesis ')' -> pop and generate header
              if (sp > 0) begin
                logic [2:0] open_idx = stack[sp-1];
                sp <= sp - 1;
                // Compute absolute positions (original index + bytes already written)
                write_start_abs <= open_idx + out_bytes;
                write_end_abs   <= i + out_bytes;
                do_write_header <= 1'b1;
              end
            end
            i <= i + 1;
          end else begin
            // All characters processed
            state <= DONE;
          end
        end

        DONE: begin
          // Hold final state; nothing else to do
        end
      endcase
    end
  end

endmodule