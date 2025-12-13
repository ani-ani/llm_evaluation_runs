module balance_checker(
  input  clk,
  input  rst_n,
  input  start,
  input  [15:0][2:0] expr,
  output reg result,
  output reg done
);

  // State encoding
  localparam IDLE       = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam DONE       = 2'b10;

  reg [1:0] state, next_state;

  // Stack: depth 8, stores 3-bit bracket codes for opens
  reg [2:0] stack [7:0];
  reg [3:0] sp;              // stack pointer: 0..8 (needs 4 bits)

  reg [4:0] index;           // 0..16 for 16 chars (5 bits)
  reg error_flag;            // set on first unbalance

  // Combinational next state logic
  always @(*) begin
    case (state)
      IDLE: begin
        if (start)
          next_state = PROCESSING;
        else
          next_state = IDLE;
      end
      PROCESSING: begin
        // After processing indices 0..15 move to DONE
        if (index == 5'd16)
          next_state = DONE;
        else
          next_state = PROCESSING;
      end
      DONE: begin
        // Wait here until start is deasserted, then go to IDLE
        if (!start)
          next_state = IDLE;
        else
          next_state = DONE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      sp         <= 4'd0;
      index      <= 5'd0;
      error_flag <= 1'b0;
      result     <= 1'b0;
      done       <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done       <= 1'b0;
          result     <= 1'b0;
          error_flag <= 1'b0;
          sp         <= 4'd0;
          index      <= 5'd0;
          if (start) begin
            // Initialization already ensured above
          end
        end

        PROCESSING: begin
          done <= 1'b0;

          if (index < 5'd16) begin
            // Fetch current character
            reg [2:0] ch;
            ch = expr[index];

            // Only act if not already in error
            if (!error_flag) begin
              case (ch)
                3'b000, // '('
                3'b010, // '{'
                3'b100: // '['
                  begin
                    // Push if stack not full
                    if (sp < 4'd8) begin
                      stack[sp] <= ch;
                      sp        <= sp + 4'd1;
                    end else begin
                      // Stack overflow -> unbalanced
                      error_flag <= 1'b1;
                    end
                  end

                3'b001: begin // ')'
                  if (sp == 0) begin
                    error_flag <= 1'b1;
                  end else if (stack[sp-1] != 3'b000) begin
                    error_flag <= 1'b1;
                  end else begin
                    sp <= sp - 4'd1;
                  end
                end

                3'b011: begin // '}'
                  if (sp == 0) begin
                    error_flag <= 1'b1;
                  end else if (stack[sp-1] != 3'b010) begin
                    error_flag <= 1'b1;
                  end else begin
                    sp <= sp - 4'd1;
                  end
                end

                3'b101: begin // ']'
                  if (sp == 0) begin
                    error_flag <= 1'b1;
                  end else if (stack[sp-1] != 3'b100) begin
                    error_flag <= 1'b1;
                  end else begin
                    sp <= sp - 4'd1;
                  end
                end

                default: begin
                  // Others ignored: do nothing
                end
              endcase
            end

            // Move to next character
            index <= index + 5'd1;
          end
        end

        DONE: begin
          // Final result computed once when entering DONE
          done <= 1'b1;
          // Balanced if no error and stack empty after 16 chars
          result <= (!error_flag && (sp == 4'd0));
          // Hold result and done until new start sequence
        end

        default: begin
          // Safe defaults
          done       <= 1'b0;
          result     <= 1'b0;
          error_flag <= 1'b0;
          sp         <= 4'd0;
          index      <= 5'd0;
        end
      endcase
    end
  end

endmodule