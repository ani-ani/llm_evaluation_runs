module tuple_concat (
  input clk,
  input rst_n,
  input start,
  input [31:0] str0,
  input [31:0] str1,
  input [31:0] str2,
  input [31:0] str3,
  output reg [127:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Register declarations
  reg [127:0] result_reg;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result_reg <= 128'b0;
      done <= 1'b0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = PROCESSING;
      end
      PROCESSING: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 128'b0;
      done <= 1'b0;
    end else begin
      case (current_state)
        PROCESSING: begin
          // Concatenate with hyphens: str0, '-', str1, '-', str2, '-', str3
          result <= {
            str0[31:0], 8'h2D, str1[31:0], 8'h2D, str2[31:0], 8'h2D, str3[31:0], 8'h00
          };
          done <= 1'b0;
        end
        DONE: begin
          done <= 1'b1;
        end
        default: begin
          result <= 128'b0;
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule