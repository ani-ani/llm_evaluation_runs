module bell_number (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  output reg [15:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    INIT,
    COMPUTE_ROW,
    COMPUTE_COL,
    UPDATE,
    DONE
  } state_t;

  // Internal state
  state_t state, next_state;
  reg [3:0] i, j;
  reg [15:0] bell [0:8][0:8];

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      i <= 0;
      j <= 0;
      for (int k = 0; k < 9; k++) begin
        for (int l = 0; l < 9; l++) begin
          bell[k][l] <= 0;
        end
      end
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
          if (n == 0) begin
            next_state = DONE;
          end else begin
            next_state = INIT;
          end
        end
      end
      INIT: next_state = COMPUTE_ROW;
      COMPUTE_ROW: next_state = COMPUTE_COL;
      COMPUTE_COL: begin
        if (j == i) begin
          next_state = UPDATE;
        end
      end
      UPDATE: begin
        if (i == n) begin
          next_state = DONE;
        end else begin
          next_state = COMPUTE_ROW;
        end
      end
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset handled in state transition
    end else begin
      case (state)
        INIT: begin
          bell[0][0] <= 1;
          i <= 1;
          j <= 0;
        end
        COMPUTE_ROW: begin
          bell[i][0] <= bell[i-1][i-1];
          j <= 1;
        end
        COMPUTE_COL: begin
          bell[i][j] <= bell[i-1][j-1] + bell[i][j-1];
          j <= j + 1;
        end
        UPDATE: begin
          if (j > i) begin
            i <= i + 1;
            j <= 0;
          end
        end
        DONE: begin
          result <= bell[n][0];
          done <= 1;
        end
        default: begin
          done <= 0;
        end
      endcase
    end
  end

endmodule