module chocolate_cutter (
  input clk,
  input rst_n,
  input start,
  input [9:0] n,
  input [9:0] m,
  input [9:0] k,
  output reg [39:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CHECK_VALIDITY,
    ITERATE_X,
    CALCULATE_Y,
    CALCULATE_AREA,
    UPDATE_RESULT,
    DONE
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [9:0] x, y;
  reg [39:0] max_area, current_area;
  reg [9:0] x_counter;
  reg [9:0] width, height;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      x <= 0;
      y <= 0;
      max_area <= 0;
      current_area <= 0;
      x_counter <= 0;
      width <= 0;
      height <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = CHECK_VALIDITY;
      end
      CHECK_VALIDITY: begin
        if (k > (n - 1) + (m - 1)) begin
          next_state = DONE;
        end else begin
          next_state = ITERATE_X;
        end
      end
      ITERATE_X: begin
        if (x_counter < min(k, n - 1)) begin
          next_state = CALCULATE_Y;
        end else begin
          next_state = DONE;
        end
      end
      CALCULATE_Y: begin
        next_state = CALCULATE_AREA;
      end
      CALCULATE_AREA: begin
        next_state = UPDATE_RESULT;
      end
      UPDATE_RESULT: begin
        next_state = ITERATE_X;
      end
      DONE: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      x <= 0;
      y <= 0;
      max_area <= 0;
      current_area <= 0;
      x_counter <= 0;
      width <= 0;
      height <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          result <= 0;
        end
        CHECK_VALIDITY: begin
          if (k > (n - 1) + (m - 1)) begin
            result <= 40'hFFFF_FFFF_FFFF;
            done <= 1;
          end
        end
        ITERATE_X: begin
          if (x_counter < min(k, n - 1)) begin
            x <= x_counter;
            x_counter <= x_counter + 1;
          end
        end
        CALCULATE_Y: begin
          y <= k - x;
        end
        CALCULATE_AREA: begin
          if (y <= m - 1) begin
            width <= n / (x + 1);
            height <= m / (y + 1);
            current_area <= width * height;
          end
        end
        UPDATE_RESULT: begin
          if (y <= m - 1 && current_area > max_area) begin
            max_area <= current_area;
          end
        end
        DONE: begin
          result <= max_area;
          done <= 1;
        end
        default: ;
      endcase
    end
  end

  // Helper function for min
  function [9:0] min;
    input [9:0] a, b;
    begin
      if (a < b) min = a;
      else min = b;
    end
  endfunction

endmodule