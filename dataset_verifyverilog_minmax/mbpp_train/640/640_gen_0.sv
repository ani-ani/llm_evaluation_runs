module remove_parentheses (
  input clk,
  input rst_n,
  input start,
  input [127:0] str_in,
  output reg [127:0] str_out,
  output reg done
);

  localparam IDLE = 1'b0;
  localparam PROCESSING = 1'b1;

  reg state, next_state;
  reg [4:0] i, next_i;           // 0..15 character index (MSB->LSB)
  reg [3:0] write_index, next_write_index; // 0..15 output byte index (MSB->LSB)
  reg skip, next_skip;            // currently inside a parenthesized group
  reg [127:0] out_reg, next_out_reg;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 5'd0;
      write_index <= 4'd0;
      skip <= 1'b0;
      out_reg <= 128'd0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      i <= next_i;
      write_index <= next_write_index;
      skip <= next_skip;
      out_reg <= next_out_reg;
      done <= (state == PROCESSING) && (i == 5'd15);
    end
  end

  // Combinational next-state logic
  always @* begin
    next_state = state;
    next_i = i;
    next_write_index = write_index;
    next_skip = skip;
    next_out_reg = out_reg;

    if (state == IDLE) begin
      if (start) begin
        next_state = PROCESSING;
        next_i = 5'd0;      // Will process str_in[127:120] next cycle
        next_write_index = 4'd0; // Output starts at MSB byte
        next_skip = 1'b0;
        next_out_reg = 128'd0;   // Zero pad the entire output
      end else begin
        next_state = IDLE;
        next_i = 5'd0;
        next_write_index = 4'd0;
        next_skip = 1'b0;
        next_out_reg = 128'd0;
      end
    end else begin // PROCESSING
      // Character being processed this cycle (MSB first)
      // i=0 => str_in[127:120], i=15 => str_in[7:0]
      wire [7:0] char_curr = str_in[127 - (i * 8) -: 8];
      // Character for lookahead of next cycle (for nested handling)
      wire [7:0] char_next = (i < 5'd15) ? str_in[127 - ((i+1) * 8) -: 8] : 8'd0;

      // Current write position (MSB-first byte index)
      // write_index 0 => byte 127:120, 1 => 119:112, ..., 15 => 7:0
      integer j;
      j = write_index;
      next_out_reg = out_reg; // default: keep current output

      // If currently skipping, just carry the skip forward
      if (skip) begin
        next_skip = 1'b1;
      end else begin
        // Not skipping: check for ')' to end a group
        next_skip = (char_curr == ")") ? 1'b1 : 1'b0;
      end

      // Decide whether to emit the current character
      if (!skip && char_curr != "(" && char_curr != ")") begin
        // Write char_curr to output at position j
        next_out_reg = out_reg;
        case (j)
          0: next_out_reg[127:120] = char_curr;
          1: next_out_reg[119:112] = char_curr;
          2: next_out_reg[111:104] = char_curr;
          3: next_out_reg[103:96]  = char_curr;
          4: next_out_reg[95:88]   = char_curr;
          5: next_out_reg[87:80]   = char_curr;
          6: next_out_reg[79:72]   = char_curr;
          7: next_out_reg[71:64]   = char_curr;
          8: next_out_reg[63:56]   = char_curr;
          9: next_out_reg[55:48]   = char_curr;
          10: next_out_reg[47:40]  = char_curr;
          11: next_out_reg[39:32]  = char_curr;
          12: next_out_reg[31:24]  = char_curr;
          13: next_out_reg[23:16]  = char_curr;
          14: next_out_reg[15:8]   = char_curr;
          15: next_out_reg[7:0]    = char_curr;
          default: next_out_reg = out_reg;
        endcase
        next_write_index = (j < 4'd15) ? (j + 4'd1) : j;
      end else begin
        // Either skipping or current char is '(' or ')', do not advance write pointer
        next_write_index = write_index;
      end

      // Nested parentheses handling: if we see '(' while not already skipping, enable skip
      if (!skip && char_curr == "(") begin
        next_skip = 1'b1;
      end
      // If we are skipping, the next ')' (when it arrives) will turn off skip in the following cycle.
      // The '(' and ')' themselves are never copied (handled by the condition above).

      // Advance character index; finish after 16 characters
      if (i < 5'd15) begin
        next_i = i + 5'd1;
        next_state = PROCESSING;
      end else begin
        next_i = 5'd0;
        next_state = IDLE; // 'done' is asserted combinatorially in the current cycle
        next_write_index = 4'd0;
        next_skip = 1'b0;
      end
    end
  end

  // Output assignment
  always @* begin
    str_out = out_reg;
  end

endmodule
