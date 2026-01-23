module digit_product_distribution (
  input clk,
  input rst_n,
  input start,
  input [15:0] L,
  input [15:0] R,
  output reg [15:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    ITERATE,
    PROCESS_NUMBER,
    UPDATE_COUNT,
    CHECK_DONE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [15:0] current_x;
  reg [15:0] temp_val;
  reg [3:0] digit_counts [1:9];
  reg [15:0] x_reg, L_reg, R_reg;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      result <= 16'b0;
      current_x <= 16'b0;
      temp_val <= 16'b0;
      for (int i = 1; i <= 9; i++) begin
        digit_counts[i] <= 4'b0;
      end
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = ITERATE;
      end
      ITERATE: begin
        if (current_x == R_reg) next_state = CHECK_DONE;
        else next_state = PROCESS_NUMBER;
      end
      PROCESS_NUMBER: begin
        next_state = UPDATE_COUNT;
      end
      UPDATE_COUNT: begin
        next_state = ITERATE;
      end
      CHECK_DONE: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Register updates
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      x_reg <= 16'b0;
      L_reg <= 16'b0;
      R_reg <= 16'b0;
    end else begin
      if (current_state == IDLE && start) begin
        x_reg <= L;
        L_reg <= L;
        R_reg <= R;
        current_x <= L;
      end else if (current_state == ITERATE && current_x != R_reg) begin
        current_x <= current_x + 1;
      end
    end
  end

  // Process number logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      temp_val <= 16'b0;
    end else begin
      if (current_state == PROCESS_NUMBER) begin
        temp_val <= current_x;
        // Process digits
        while (temp_val > 9) begin
          reg [15:0] product = 1;
          reg [15:0] num = temp_val;
          while (num > 0) begin
            reg [3:0] digit = num % 10;
            if (digit != 0) begin
              product = product * digit;
            end
            num = num / 10;
          end
          temp_val <= product;
        end
      end
    end
  end

  // Update counts
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 1; i <= 9; i++) begin
        digit_counts[i] <= 4'b0;
      end
    end else begin
      if (current_state == UPDATE_COUNT) begin
        if (temp_val >= 1 && temp_val <= 9) begin
          digit_counts[temp_val] <= digit_counts[temp_val] + 1;
        end
      end
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 16'b0;
      done <= 1'b0;
    end else begin
      if (current_state == DONE) begin
        // Pack counts into result
        result <= {digit_counts[9], digit_counts[8], digit_counts[7], digit_counts[6],
                   digit_counts[5], digit_counts[4], digit_counts[3], digit_counts[2],
                   digit_counts[1][3:0]};
        done <= 1'b1;
      end else if (current_state == IDLE && start) begin
        done <= 1'b0;
      end
    end
  end

endmodule