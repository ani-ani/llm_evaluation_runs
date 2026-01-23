module colon_tuplex (
  input clk,
  input rst_n,
  input start,
  input [2:0] m,
  input [7:0] n,
  input [7:0] tuplex_0,
  input [7:0] tuplex_1,
  input [7:0] tuplex_2,
  input [7:0] tuplex_3,
  output reg [7:0] result_0,
  output reg [7:0] result_1,
  output reg [7:0] result_2,
  output reg [7:0] result_3,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    case (current_state)
      IDLE: begin
        if (start) next_state = PROCESSING;
        else next_state = IDLE;
      end
      PROCESSING: next_state = DONE;
      DONE: begin
        if (!start) next_state = IDLE;
        else next_state = DONE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result_0 <= 8'b0;
      result_1 <= 8'b0;
      result_2 <= 8'b0;
      result_3 <= 8'b0;
      done <= 1'b0;
    end else begin
      case (current_state)
        IDLE: begin
          result_0 <= 8'b0;
          result_1 <= 8'b0;
          result_2 <= 8'b0;
          result_3 <= 8'b0;
          done <= 1'b0;
        end
        PROCESSING: begin
          case (m)
            3'd0: begin
              result_0 <= n;
              result_1 <= tuplex_1;
              result_2 <= tuplex_2;
              result_3 <= tuplex_3;
            end
            3'd1: begin
              result_0 <= tuplex_0;
              result_1 <= n;
              result_2 <= tuplex_2;
              result_3 <= tuplex_3;
            end
            3'd2: begin
              result_0 <= tuplex_0;
              result_1 <= tuplex_1;
              result_2 <= n;
              result_3 <= tuplex_3;
            end
            3'd3: begin
              result_0 <= tuplex_0;
              result_1 <= tuplex_1;
              result_2 <= tuplex_2;
              result_3 <= n;
            end
            default: begin
              result_0 <= tuplex_0;
              result_1 <= tuplex_1;
              result_2 <= tuplex_2;
              result_3 <= tuplex_3;
            end
          endcase
          done <= 1'b0;
        end
        DONE: begin
          // Hold the results
          done <= 1'b1;
        end
      endcase
    end
  end

endmodule