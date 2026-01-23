module multiply_int (
  input clk,
  input rst_n,
  input start,
  input signed [15:0] x,
  input signed [15:0] y,
  output reg signed [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  // Internal registers
  reg [1:0] current_state, next_state;
  reg signed [15:0] x_reg, y_reg;
  reg signed [31:0] acc;
  reg [15:0] abs_y;
  reg res_sign;
  reg [15:0] counter;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result <= 0;
      done <= 0;
      x_reg <= 0;
      y_reg <= 0;
      acc <= 0;
      abs_y <= 0;
      res_sign <= 0;
      counter <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = PROCESSING;
        end
      end
      PROCESSING: begin
        if (counter == 0) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      x_reg <= 0;
      y_reg <= 0;
      acc <= 0;
      abs_y <= 0;
      res_sign <= 0;
      counter <= 0;
    end else begin
      case (current_state)
        IDLE: begin
          if (start) begin
            x_reg <= x;
            y_reg <= y;
            abs_y <= (y_reg < 0) ? -y_reg : y_reg;
            res_sign <= (x_reg[15] ^ y_reg[15]);
            if (abs_y == 0) begin
              acc <= 0;
            end else begin
              acc <= 0;
              counter <= abs_y;
            end
          end
        end
        PROCESSING: begin
          if (counter != 0) begin
            acc <= acc + x_reg;
            counter <= counter - 1;
          end
        end
        DONE: begin
          if (res_sign) begin
            result <= -acc;
          end else begin
            result <= acc;
          end
          done <= 1;
        end
      endcase
    end
  end

endmodule