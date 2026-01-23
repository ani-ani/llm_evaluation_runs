module even_power_sum (
  input clk,
  input rst_n,
  input start,
  input [4:0] n,
  output reg [63:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    COMPUTE,
    DONE
  } state_t;

  state_t state, next_state;
  reg [4:0] i;
  reg [63:0] accumulator;
  reg [31:0] even_num;
  reg [63:0] power;

  // Power calculation stages
  reg [31:0] stage1, stage2, stage3, stage4, stage5;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 0;
      accumulator <= 0;
      result <= 0;
      done <= 0;
      even_num <= 0;
      stage1 <= 0;
      stage2 <= 0;
      stage3 <= 0;
      stage4 <= 0;
      stage5 <= 0;
    end else begin
      state <= next_state;
      if (state == COMPUTE) begin
        i <= i + 1;
        accumulator <= accumulator + power;
        even_num <= 2 * i;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = COMPUTE;
        else next_state = IDLE;
      end
      COMPUTE: begin
        if (i == n) next_state = DONE;
        else next_state = COMPUTE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
        else next_state = DONE;
      end
    endcase
  end

  // Power calculation pipeline
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      stage1 <= 0;
      stage2 <= 0;
      stage3 <= 0;
      stage4 <= 0;
      stage5 <= 0;
    end else begin
      stage1 <= even_num * even_num; // x^2
      stage2 <= stage1 * even_num;   // x^3
      stage3 <= stage2 * even_num;   // x^4
      stage4 <= stage3 * even_num;   // x^5
      stage5 <= stage4 << 16;        // Convert to Q16.16
    end
  end

  assign power = stage5;

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
    end else begin
      if (state == COMPUTE && i == n) begin
        result <= accumulator;
        done <= 1;
      end else if (state == IDLE) begin
        result <= 0;
        done <= 0;
      end
    end
  end

endmodule