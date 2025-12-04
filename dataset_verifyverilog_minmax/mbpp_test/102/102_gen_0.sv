module snake_to_camel (
  input clk,
  input rst_n,
  input start,
  input [79:0] snake_str,
  input [3:0] length,
  output reg [79:0] camel_str,
  output reg done
);

  typedef enum logic [1:0] { IDLE = 2'b00, PROCESSING = 2'b01, DONE = 2'b10 } state_t;
  state_t state, next_state;

  reg [3:0] idx;        // index of byte being processed (0..9)
  reg [3:0] out_idx;    // index of next write position in camel_str
  reg capitalize_next;  // 1 if next alphabetic char should be uppercased

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = PROCESSING;
      end
      PROCESSING: begin
        if (idx == 4'd9 || (length != 4'd0 && idx == (length - 1))) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (start) next_state = PROCESSING;  // allow re-start while still DONE
        else if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // State and control registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      idx <= 4'd0;
      out_idx <= 4'd0;
      capitalize_next <= 1'b0;
      camel_str <= 80'h0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      done <= 1'b0; // default; set in DONE state below

      case (state)
        IDLE: begin
          idx <= 4'd0;
          out_idx <= 4'd0;
          capitalize_next <= 1'b0;
          camel_str <= 80'h0;
        end

        PROCESSING: begin
          if (idx < 4'd10) begin
            logic [7:0] ch;
            ch = snake_str[8*idx +: 8];

            // Determine if we are still within the valid input length
            if (length != 4'd0 && idx < length) begin
              logic [7:0] out_ch;
              if (ch == 8'h5F) begin
                // underscore: omit and mark next non-underscore for capitalization
                out_ch = 8'h00;
                capitalize_next <= 1'b1;
              end else begin
                if ((ch >= 8'h61 && ch <= 8'h7A) && capitalize_next) begin
                  out_ch = ch - 8'd32; // to uppercase
                end else begin
                  out_ch = ch; // unchanged otherwise
                end
                capitalize_next <= 1'b0;
              end
              // Write to camel_str byte at out_idx
              camel_str[8*out_idx +: 8] <= out_ch;
              out_idx <= out_idx + 1;
            end

            idx <= idx + 1;
          end
        end

        DONE: begin
          done <= 1'b1;
          // Keep outputs stable; next state may go to IDLE on start deassert
        end

        default: ;
      endcase
    end
  end

endmodule