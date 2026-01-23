module clock_path (
  input clk,
  input rst_n,
  input start,
  input [5:0] h,
  input [5:0] m,
  input [5:0] s,
  input [5:0] t1,
  input [5:0] t2,
  output reg result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CALC_POS,
    CHECK_CW,
    CHECK_CCW,
    FINISH
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [5:0] hour_idx, min_idx, sec_idx;
  reg [5:0] start_idx, end_idx;
  reg [5:0] counter;
  reg cw_blocked, ccw_blocked;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = CALC_POS;
      end
      CALC_POS: next_state = CHECK_CW;
      CHECK_CW: next_state = CHECK_CCW;
      CHECK_CCW: next_state = FINISH;
      FINISH: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      hour_idx <= 0;
      min_idx <= 0;
      sec_idx <= 0;
      start_idx <= 0;
      end_idx <= 0;
      counter <= 0;
      cw_blocked <= 0;
      ccw_blocked <= 0;
    end else begin
      case (current_state)
        CALC_POS: begin
          hour_idx <= (h % 12) * 5;
          min_idx <= m;
          sec_idx <= s;
          start_idx <= (t1 % 12) * 5;
          end_idx <= (t2 % 12) * 5;
          counter <= 0;
          cw_blocked <= 0;
          ccw_blocked <= 0;
        end
        CHECK_CW: begin
          if (counter == 0) begin
            counter <= start_idx + 1;
            cw_blocked <= 0;
          end else begin
            if (counter == end_idx) begin
              // Path check complete
            end else if (counter == hour_idx || counter == min_idx || counter == sec_idx) begin
              cw_blocked <= 1;
            end
            counter <= (counter == 59) ? 0 : counter + 1;
          end
        end
        CHECK_CCW: begin
          if (counter == 0) begin
            counter <= start_idx - 1;
            ccw_blocked <= 0;
          end else begin
            if (counter == end_idx) begin
              // Path check complete
            end else if (counter == hour_idx || counter == min_idx || counter == sec_idx) begin
              ccw_blocked <= 1;
            end
            counter <= (counter == 0) ? 59 : counter - 1;
          end
        end
        FINISH: begin
          result <= ~(cw_blocked & ccw_blocked);
          done <= 1;
        end
        default: begin
          done <= 0;
        end
      endcase
    end
  end

endmodule