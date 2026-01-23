module median_two_sorted_arrays (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [7:0] arr1 [0:7],
  input [7:0] arr2 [0:7],
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [2:0] i, j;
  reg [2:0] count;
  reg [7:0] m1, m2;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      i <= 0;
      j <= 0;
      count <= 0;
      m1 <= 0;
      m2 <= 0;
      done <= 0;
      result <= 0;
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
        if (count == n + 1 || i == n || j == n) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Processing logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i <= 0;
      j <= 0;
      count <= 0;
      m1 <= 0;
      m2 <= 0;
    end else if (current_state == PROCESSING) begin
      if (count == 0) begin
        m1 <= 0;
        m2 <= (arr1[i] < arr2[j]) ? arr1[i] : arr2[j];
        if (arr1[i] < arr2[j]) i <= i + 1;
        else j <= j + 1;
      end else begin
        m1 <= m2;
        m2 <= (arr1[i] < arr2[j]) ? arr1[i] : arr2[j];
        if (arr1[i] < arr2[j]) i <= i + 1;
        else j <= j + 1;
      end
      count <= count + 1;
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      result <= 0;
    end else if (current_state == DONE) begin
      done <= 1;
      // Convert to Q16.16: (m1 + m2) / 2
      result <= ({16'd0, m1} + {16'd0, m2}) >> 1;
    end else begin
      done <= 0;
    end
  end

endmodule