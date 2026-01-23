module digits_product (
  input clk,
  input rst_n,
  input start,
  input [7:0] number,
  output reg [15:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    INIT,
    PROCESS_DIGIT_0,
    PROCESS_DIGIT_1,
    PROCESS_DIGIT_2,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [15:0] product_reg;
  reg [7:0] digit_reg;
  reg [7:0] temp_number;
  reg [1:0] digit_counter;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      product_reg <= 16'b0;
      digit_reg <= 8'b0;
      temp_number <= 8'b0;
      digit_counter <= 2'b0;
      result <= 16'b0;
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
        if (start) next_state = INIT;
        else next_state = IDLE;
      end
      INIT: next_state = PROCESS_DIGIT_0;
      PROCESS_DIGIT_0: next_state = PROCESS_DIGIT_1;
      PROCESS_DIGIT_1: next_state = PROCESS_DIGIT_2;
      PROCESS_DIGIT_2: next_state = DONE;
      DONE: begin
        if (start) next_state = INIT;
        else next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      product_reg <= 16'b0;
      digit_reg <= 8'b0;
      temp_number <= 8'b0;
      digit_counter <= 2'b0;
    end else begin
      case (current_state)
        INIT: begin
          product_reg <= 16'b1;
          temp_number <= number;
          digit_counter <= 2'b0;
        end
        PROCESS_DIGIT_0: begin
          digit_reg <= temp_number % 10;
          if (digit_reg[0]) product_reg <= product_reg * digit_reg;
          temp_number <= temp_number / 10;
        end
        PROCESS_DIGIT_1: begin
          digit_reg <= temp_number % 10;
          if (digit_reg[0]) product_reg <= product_reg * digit_reg;
          temp_number <= temp_number / 10;
        end
        PROCESS_DIGIT_2: begin
          digit_reg <= temp_number % 10;
          if (digit_reg[0]) product_reg <= product_reg * digit_reg;
        end
        DONE: begin
          result <= (product_reg == 16'b1) ? 16'b0 : product_reg;
          done <= 1'b1;
        end
        default: begin
          product_reg <= 16'b0;
          digit_reg <= 8'b0;
          temp_number <= 8'b0;
          digit_counter <= 2'b0;
          result <= 16'b0;
          done <= 1'b0;
        end
      endcase
    end
  end

  // Reset done signal when not in DONE state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
    end else if (current_state != DONE) begin
      done <= 1'b0;
    end
  end

endmodule