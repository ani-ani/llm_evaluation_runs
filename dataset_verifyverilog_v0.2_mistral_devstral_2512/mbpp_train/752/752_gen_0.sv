module jacobsthal (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  output reg [12:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CHECK,
    COMPUTE,
    DONE
  } state_t;

  // State machine signals
  state_t state, next_state;
  reg [12:0] j_prev, j_prev2;
  reg [3:0] i;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      j_prev <= 0;
      j_prev2 <= 0;
      i <= 0;
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
        if (start) next_state = CHECK;
      end
      CHECK: begin
        next_state = COMPUTE;
        if (n == 0) begin
          result = 0;
          next_state = DONE;
        end else if (n == 1) begin
          result = 1;
          next_state = DONE;
        end
      end
      COMPUTE: begin
        if (i == n) begin
          result = j_prev;
          next_state = DONE;
        end
      end
      DONE: begin
        if (start) next_state = CHECK;
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      j_prev <= 0;
      j_prev2 <= 0;
      i <= 0;
    end else begin
      case (state)
        CHECK: begin
          j_prev <= 1;
          j_prev2 <= 0;
          i <= 2;
        end
        COMPUTE: begin
          if (i != n) begin
            j_prev2 <= j_prev;
            j_prev <= j_prev + (j_prev2 << 1);
            i <= i + 1;
          end
        end
        DONE: begin
          done <= 1;
        end
        default: begin
          done <= 0;
        end
      endcase
    end
  end

endmodule