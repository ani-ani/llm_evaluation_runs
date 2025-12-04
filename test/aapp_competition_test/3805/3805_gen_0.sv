module wire_untangle(
  input  clk,
  input  rst_n,
  input  start,
  input  [15:0] data,
  output reg done,
  output reg result
);

  // State encoding
  localparam IDLE       = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam DONE       = 2'b10;

  reg [1:0] state, next_state;

  // Index for 8 characters (0..7)
  reg [2:0] idx;

  // Stack for up to 8 entries, each 1 bit ('0' or '1')
  reg [7:0] stack_mem;
  reg [3:0] stack_depth; // 0..8

  wire [1:0] curr_pair;
  wire       curr_char;

  // Select current 2-bit character pair from data
  assign curr_pair = data[(idx*2)+1 -: 2];
  assign curr_char = curr_pair[0]; // LSB encodes '-' or '+'

  // Next-state logic
  always @(*) begin
    case (state)
      IDLE: begin
        if (start)
          next_state = PROCESSING;
        else
          next_state = IDLE;
      end
      PROCESSING: begin
        if (idx == 3'd7)
          next_state = DONE;
        else
          next_state = PROCESSING;
      end
      DONE: begin
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
      state       <= IDLE;
      idx         <= 3'd0;
      stack_depth <= 4'd0;
      done        <= 1'b0;
      result      <= 1'b0;
      stack_mem   <= 8'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done        <= 1'b0;
          result      <= 1'b0;
          idx         <= 3'd0;
          stack_depth <= 4'd0;
          stack_mem   <= 8'b0;
        end

        PROCESSING: begin
          // Stack algorithm for current char
          if (stack_depth == 4'd0) begin
            // Push when stack empty
            stack_mem[0] <= curr_char;
            stack_depth  <= 4'd1;
          end else begin
            // Compare with top of stack
            if (stack_mem[stack_depth-1] == curr_char) begin
              // Pop
              stack_depth <= stack_depth - 1'b1;
            end else begin
              // Push
              stack_mem[stack_depth] <= curr_char;
              stack_depth            <= stack_depth + 1'b1;
            end
          end

          // Increment index
          if (idx != 3'd7)
            idx <= idx + 1'b1;
        end

        DONE: begin
          done   <= 1'b1;
          result <= (stack_depth == 4'd0) ? 1'b1 : 1'b0;
          // Hold idx, stack_depth, stack_mem until return to IDLE
        end

        default: begin
          // Safe defaults
          done   <= 1'b0;
          result <= 1'b0;
        end
      endcase
    end
  end

endmodule