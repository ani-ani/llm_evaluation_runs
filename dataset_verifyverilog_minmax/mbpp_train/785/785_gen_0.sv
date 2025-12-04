module tuple_str_to_int (
  input clk,
  input rst_n,
  input start,
  input [15:0][7:0] str_in,
  output reg [9:0] num1,
  output reg [9:0] num2,
  output reg [9:0] num3,
  output reg done
);

  typedef enum logic [2:0] {IDLE, PARSE_NUM1, PARSE_NUM2, PARSE_NUM3, DONE} state_t;
  state_t state, next_state;

  reg [3:0] idx;             // 0..15
  reg [3:0] next_idx;
  reg [9:0] cur_num;         // accumulator for the number being parsed
  reg [9:0] next_cur_num;
  reg [1:0] target;          // 0->num1, 1->num2, 2->num3
  reg [1:0] next_target;
  reg started;               // indicates we have seen a digit in the current number
  reg next_started;

  // Current number register update (registered so outputs are valid in the 3rd cycle after start)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) cur_num <= '0;
    else cur_num <= next_cur_num;
  end

  // FSM state and auxiliary regs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      idx <= '0;
      target <= '0;
      started <= '0;
    end else begin
      state <= next_state;
      idx <= next_idx;
      target <= next_target;
      started <= next_started;
    end
  end

  // Outputs registered as specified
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      num1 <= '0;
      num2 <= '0;
      num3 <= '0;
      done <= '0;
    end else begin
      case (state)
        PARSE_NUM2: if (next_state == PARSE_NUM3) num1 <= next_cur_num;
        PARSE_NUM3: if (next_state == DONE)      num2 <= next_cur_num;
        DONE:                                   num3 <= cur_num; // final store
        default: ; // no change
      endcase
      done <= (next_state == DONE);
    end
  end

  // FSM next-state logic and datapath
  always @(*) begin
    // defaults (avoid latches)
    next_state   = state;
    next_idx     = idx;
    next_cur_num = cur_num;
    next_target  = target;
    next_started = started;

    unique case (state)
      IDLE: begin
        next_idx     = '0;
        next_cur_num = '0;
        next_target  = '0;
        next_started = '0;
        if (start) begin
          next_state = PARSE_NUM1;
        end
      end

      PARSE_NUM1: begin
        if (idx < 16) begin
          if (str_in[idx] >= "0" && str_in[idx] <= "9") begin
            next_cur_num = (cur_num * 10) + (str_in[idx] - "0");
            next_started = 1'b1;
            next_idx     = idx + 1;
          end else if (started) begin
            // non-digit after at least one digit: store and move on
            next_state   = PARSE_NUM2;
            next_cur_num = '0;
            next_target  = 2'd1;
            next_started = '0;
            next_idx     = idx + 1;
          end else begin
            // still skipping before first digit
            next_idx = idx + 1;
          end
        end else begin
          // Reached end of string
          if (started) begin
            next_state   = DONE; // num1 is in cur_num; done will register it next cycle
            next_started = '0;
            next_cur_num = '0;
            next_target  = '0;
            next_idx     = '0;
          end else begin
            next_state   = DONE; // no digits found => all zeros
            next_started = '0;
            next_cur_num = '0;
            next_target  = '0;
            next_idx     = '0;
          end
        end
      end

      PARSE_NUM2: begin
        if (idx < 16) begin
          if (str_in[idx] >= "0" && str_in[idx] <= "9") begin
            next_cur_num = (cur_num * 10) + (str_in[idx] - "0");
            next_started = 1'b1;
            next_idx     = idx + 1;
          end else if (started) begin
            next_state   = PARSE_NUM3;
            next_cur_num = '0;
            next_target  = 2'd2;
            next_started = '0;
            next_idx     = idx + 1;
          end else begin
            next_idx = idx + 1;
          end
        end else begin
          if (started) begin
            next_state   = DONE; // num2 is in cur_num
            next_started = '0;
            next_cur_num = '0;
            next_target  = '0;
            next_idx     = '0;
          end else begin
            next_state   = DONE; // no digits found => zero
            next_started = '0;
            next_cur_num = '0;
            next_target  = '0;
            next_idx     = '0;
          end
        end
      end

      PARSE_NUM3: begin
        if (idx < 16) begin
          if (str_in[idx] >= "0" && str_in[idx] <= "9") begin
            next_cur_num = (cur_num * 10) + (str_in[idx] - "0");
            next_started = 1'b1;
            next_idx     = idx + 1;
          end else if (started) begin
            // Final non-digit: done in next cycle, num3 is in cur_num
            next_state   = DONE;
            next_cur_num = '0;
            next_target  = '0;
            next_started = '0;
            next_idx     = idx + 1;
          end else begin
            next_idx = idx + 1;
          end
        end else begin
          // End of string reached
          if (started) begin
            next_state   = DONE; // num3 is in cur_num
            next_started = '0;
            next_cur_num = '0;
            next_target  = '0;
            next_idx     = '0;
          end else begin
            next_state   = DONE; // no digits found => zero
            next_started = '0;
            next_cur_num = '0;
            next_target  = '0;
            next_idx     = '0;
          end
        end
      end

      DONE: begin
        // Hold done for 1 cycle, then return to IDLE (meets 3-cycle latency: start + 3 cycles)
        next_state   = IDLE;
        next_cur_num = '0;
        next_target  = '0;
        next_started = '0;
        next_idx     = '0;
      end

      default: begin
        next_state   = IDLE;
        next_idx     = '0;
        next_cur_num = '0;
        next_target  = '0;
        next_started = '0;
      end
    endcase
  end

endmodule
