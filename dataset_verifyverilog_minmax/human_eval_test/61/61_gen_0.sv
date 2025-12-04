module bracket_checker(
  input clk,
  input rst_n,
  input start,
  input [7:0] brackets,
  output reg result,
  output reg done
);
  localparam IDLE = 2'b00;
  localparam PROC = 2'b01;
  localparam FINAL = 2'b10;

  reg [1:0] state, next_state;
  reg [3:0] idx;     // 0..7
  reg [3:0] next_idx;
  reg signed [3:0] cnt; // -8..8 fits in 4 bits signed
  reg signed [3:0] next_cnt;
  reg invalid_flag;
  reg next_invalid;
  reg next_done;
  reg next_result;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      idx <= 4'd0;
      cnt <= 4'd0;
      invalid_flag <= 1'b0;
      result <= 1'b0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      idx <= next_idx;
      cnt <= next_cnt;
      invalid_flag <= next_invalid;
      result <= next_result;
      done <= next_done;
    end
  end

  always @(*) begin
    next_state = state;
    next_idx = idx;
    next_cnt = cnt;
    next_invalid = invalid_flag;
    next_result = result;
    next_done = 1'b0;

    case (state)
      IDLE: begin
        next_idx = 4'd0;
        next_cnt = 4'd0;
        next_invalid = 1'b0;
        next_done = 1'b0;
        next_result = 1'b0;
        if (start) begin
          next_state = PROC;
        end else begin
          next_state = IDLE;
        end
      end

      PROC: begin
        if (invalid_flag) begin
          next_state = FINAL;
        end else begin
          if (brackets[idx] == 8'h28) begin
            next_cnt = cnt + 1;
          end else if (brackets[idx] == 8'h29) begin
            next_cnt = cnt - 1;
          end else begin
            next_cnt = cnt;
          end
          if (next_cnt < 0) begin
            next_invalid = 1'b1;
          end else begin
            next_invalid = invalid_flag;
          end
          if (idx == 4'd7) begin
            next_state = FINAL;
          end else begin
            next_state = PROC;
            next_idx = idx + 1;
          end
        end
      end

      FINAL: begin
        next_done = 1'b1;
        if (invalid_flag) begin
          next_result = 1'b0;
        end else begin
          next_result = (cnt == 0);
        end
        if (start) begin
          next_state = PROC;
          next_idx = 4'd0;
          next_cnt = 4'd0;
          next_invalid = 1'b0;
        end else begin
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end
endmodule