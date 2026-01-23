module perrin_sum (
  input clk,
  input rst_n,
  input start,
  input [4:0] N,
  output reg [15:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    INIT,
    CALCULATE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [15:0] a, b, c, sum;
  reg [3:0] i;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      result <= 16'b0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = INIT;
      end
      INIT: begin
        next_state = CALCULATE;
      end
      CALCULATE: begin
        if (i == N) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a <= 16'b0;
      b <= 16'b0;
      c <= 16'b0;
      sum <= 16'b0;
      i <= 4'b0;
      done <= 1'b0;
    end else begin
      case (current_state)
        INIT: begin
          a <= 16'd3;
          b <= 16'd0;
          c <= 16'd2;
          sum <= 16'd3;
          i <= 4'b0;
          done <= 1'b0;
        end
        CALCULATE: begin
          if (i < N) begin
            if (i == 4'd1) begin
              sum <= sum + 16'd0;
              a <= b;
              b <= c;
              c <= a + b;
            end else if (i == 4'd2) begin
              sum <= sum + 16'd2;
              a <= b;
              b <= c;
              c <= a + b;
            end else if (i >= 4'd3) begin
              reg [15:0] d = a + b;
              sum <= sum + d;
              a <= b;
              b <= c;
              c <= d;
            end
            i <= i + 1'b1;
          end
        end
        DONE: begin
          result <= sum;
          done <= 1'b1;
        end
        default: begin
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule