module sum_collatz (
  input clk,
  input rst_n,
  input start,
  input [15:0] L,
  input [15:0] R,
  output reg [31:0] sum,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CALC_F,
    ACCUM,
    INCREMENT_X,
    DONE
  } state_t;

  state_t state, next_state;
  reg [15:0] current_X;
  reg [31:0] iterations;
  reg [31:0] temp_sum;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      sum <= 32'b0;
      done <= 1'b0;
      current_X <= 16'b0;
      iterations <= 32'b0;
      temp_sum <= 32'b0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = CALC_F;
          current_X = L;
          temp_sum = 32'b0;
          done = 1'b0;
        end
      end
      CALC_F: begin
        if (current_X == 1) begin
          next_state = ACCUM;
        end
      end
      ACCUM: begin
        next_state = INCREMENT_X;
      end
      INCREMENT_X: begin
        if (current_X == R) begin
          next_state = DONE;
        end else begin
          next_state = CALC_F;
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
      sum <= 32'b0;
      done <= 1'b0;
    end else begin
      case (state)
        CALC_F: begin
          if (current_X != 1) begin
            if (current_X[0] == 1'b0) begin
              current_X <= current_X >> 1;
            end else begin
              current_X <= current_X + 1;
            end
            iterations <= iterations + 1;
          end
        end
        ACCUM: begin
          temp_sum <= temp_sum + iterations;
          iterations <= 32'b0;
        end
        INCREMENT_X: begin
          if (current_X != R) begin
            current_X <= current_X + 1;
          end
        end
        DONE: begin
          sum <= temp_sum;
          done <= 1'b1;
        end
      endcase
    end
  end

endmodule