module sum_squares (
  input clk,
  input rst_n,
  input start,
  input [3:0] length,
  input signed [15:0] data [0:15],
  output reg signed [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  // Internal registers
  reg [1:0] current_state, next_state;
  reg [3:0] idx;
  reg signed [31:0] acc;
  reg [31:0] temp_square, temp_cube;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      idx <= 0;
      acc <= 0;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
      if (current_state == PROCESSING && idx < length) begin
        idx <= idx + 1;
      end
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
        if (idx == length - 1) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Processing logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      acc <= 0;
    end else if (current_state == PROCESSING && idx < length) begin
      // Compute transformations
      if (idx % 3 == 0) begin
        temp_square = $signed(data[idx]) * $signed(data[idx]);
        acc <= acc + temp_square;
      end else if (idx % 4 == 0) begin
        temp_cube = $signed(data[idx]) * $signed(data[idx]) * $signed(data[idx]);
        acc <= acc + temp_cube;
      end else begin
        acc <= acc + $signed(data[idx]);
      end
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
    end else begin
      if (current_state == DONE) begin
        result <= acc;
        done <= 1;
      end else begin
        done <= 0;
      end
    end
  end

endmodule