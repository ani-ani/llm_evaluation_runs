module average_of_cubes (
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CALC_SUM,
    DIVIDE,
    DONE
  } state_t;

  state_t state, next_state;
  reg [7:0] i;
  reg [31:0] sum;
  reg [31:0] temp_result;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 0;
      sum <= 0;
      temp_result <= 0;
      result <= 0;
      done <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = CALC_SUM;
      end
      CALC_SUM: begin
        if (i == n) next_state = DIVIDE;
      end
      DIVIDE: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i <= 0;
      sum <= 0;
      temp_result <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          i <= 0;
          sum <= 0;
          done <= 0;
        end
        CALC_SUM: begin
          if (i < n) begin
            sum <= sum + (i * i * i);
            i <= i + 1;
          end
        end
        DIVIDE: begin
          // Convert to Q16.16: multiply by 2^16 (65536)
          temp_result <= (sum << 16) / n;
          result <= temp_result;
        end
        DONE: begin
          done <= 1;
        end
      endcase
    end
  end

endmodule