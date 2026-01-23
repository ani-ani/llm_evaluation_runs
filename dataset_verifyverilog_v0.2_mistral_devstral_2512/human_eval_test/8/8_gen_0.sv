module sum_product (
  input clk,
  input rst_n,
  input start,
  input [4:0] array_len,
  input [15:0] array_data [0:15],
  output reg [31:0] sum_out,
  output reg [31:0] product_out,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [3:0] index;
  reg [31:0] sum_reg;
  reg [31:0] product_reg;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      index <= 0;
      sum_reg <= 0;
      product_reg <= 1;
      sum_out <= 0;
      product_out <= 1;
      done <= 0;
    end else begin
      current_state <= next_state;
      if (next_state == PROCESSING) begin
        index <= index + 1;
        sum_reg <= sum_reg + array_data[index];
        product_reg <= product_reg * array_data[index];
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          if (array_len == 0) begin
            next_state = DONE;
          end else begin
            next_state = PROCESSING;
            index = 0;
            sum_reg = array_data[0];
            product_reg = array_data[0];
          end
        end
      end
      PROCESSING: begin
        if (index == array_len - 1) begin
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

  // Output logic
  always @(*) begin
    case (current_state)
      IDLE: begin
        sum_out = 0;
        product_out = 1;
        done = 0;
      end
      PROCESSING: begin
        sum_out = sum_reg;
        product_out = product_reg;
        done = 0;
      end
      DONE: begin
        if (array_len == 0) begin
          sum_out = 0;
          product_out = 1;
        end else begin
          sum_out = sum_reg;
          product_out = product_reg;
        end
        done = 1;
      end
    endcase
  end

endmodule