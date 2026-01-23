module empty_list (
  input clk,
  input rst_n,
  input start,
  input [7:0] length,
  output reg [63:0] result_array,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE,
    FILL,
    DONE
  } state_t;

  state_t current_state, next_state;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result_array <= 64'b0;
      done <= 1'b0;
    end else begin
      current_state <= next_state;
    end
  end

  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = FILL;
        end
      end
      FILL: begin
        next_state = DONE;
      end
      DONE: begin
        next_state = IDLE;
      end
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result_array <= 64'b0;
      done <= 1'b0;
    end else begin
      case (current_state)
        FILL: begin
          result_array <= 64'b0;
          done <= 1'b0;
        end
        DONE: begin
          done <= 1'b1;
        end
        default: begin
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule