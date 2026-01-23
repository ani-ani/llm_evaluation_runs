module sum_of_products (
  input clk,
  input rst_n,
  input start,
  input [7:0] array_size,
  input [7:0] arr [0:7],
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t state, next_state;
  reg [2:0] index;
  reg [31:0] res;
  reg [31:0] total;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      index <= 0;
      res <= 0;
      total <= 0;
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
        if (start) next_state = PROCESSING;
      end
      PROCESSING: begin
        if (index == 0) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Processing logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      index <= 0;
      res <= 0;
      total <= 0;
    end else if (state == PROCESSING) begin
      if (index == array_size - 1) begin
        res <= arr[index];
        total <= arr[index];
        index <= index - 1;
      end else if (index >= 0) begin
        res <= arr[index] * (1 + res);
        total <= total + res;
        index <= index - 1;
      end
    end else if (state == DONE) begin
      result <= total;
      done <= 1;
    end else begin
      done <= 0;
    end
  end

endmodule