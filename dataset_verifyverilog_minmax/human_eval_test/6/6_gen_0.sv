module paren_depth_calculator (
  input clk,
  input rst_n,
  input start,
  input [127:0] group_string,
  output reg [2:0] max_depth,
  output reg done
);

  // FSM state encoding
  localparam IDLE       = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam DONE       = 2'b10;

  reg [1:0] state, next_state;
  reg [3:0] idx;              // 4-bit index for 16 characters
  reg [2:0] current_depth;    // internal current depth (0..7)
  reg [7:0] char_byte;        // current character byte

  // Next-state logic (combinational)
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = PROCESSING;
      end
      PROCESSING: begin
        if (char_byte == 8'h00) next_state = DONE;
        else if (idx == 4'd15)  next_state = DONE;
        else                    next_state = PROCESSING;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic with synchronous reset
  always @(posedge clk) begin
    if (!rst_n) begin
      state        <= IDLE;
      idx          <= 4'd0;
      current_depth<= 3'd0;
      max_depth    <= 3'd0;
      done         <= 1'b0;
      char_byte    <= 8'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          idx          <= 4'd0;
          current_depth<= 3'd0;
          max_depth    <= 3'd0;
          done         <= 1'b0;
          char_byte    <= 8'd0;
        end

        PROCESSING: begin
          // Select current character (MSB-first: index 0 -> [127:120], 1 -> [119:112], ...)
          char_byte <= group_string[127 - (idx * 8) -: 8];

          if (char_byte == 8'h00) begin
            // Early termination on null
            done <= 1'b1;
          end else begin
            // Update depth on '(' or ')'
            if (char_byte == 8'h28) begin // '('
              if (current_depth < 3'd7) current_depth <= current_depth + 1;
            end else if (char_byte == 8'h29) begin // ')'
              if (current_depth > 3'd0) current_depth <= current_depth - 1;
            end

            // Track maximum depth
            if (current_depth > max_depth) max_depth <= current_depth;

            // Advance index; set done after the last character
            if (idx == 4'd15) done <= 1'b1;
            else idx <= idx + 1;
          end
        end

        DONE: begin
          // Hold outputs until start deasserts
          done      <= 1'b1;
          max_depth <= max_depth;
          idx       <= 4'd0;
          char_byte <= 8'd0;
          current_depth <= 3'd0;
        end

        default: begin
          // Should never happen, but safe defaults
          done         <= 1'b0;
          max_depth    <= 3'd0;
          idx          <= 4'd0;
          current_depth<= 3'd0;
          char_byte    <= 8'd0;
        end
      endcase
    end
  end

endmodule
