module odd_equivalent (
  input clk,
  input rst_n,
  input start,
  input [7:0] s,
  input [3:0] n,
  output reg [3:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    ROTATING,
    COUNTING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [7:0] rotated_s;
  reg [3:0] rotation_count;
  reg [3:0] temp_result;
  reg [7:0] parity_check;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result <= 0;
      done <= 0;
      rotation_count <= 0;
      temp_result <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    case (current_state)
      IDLE: begin
        if (start) next_state = ROTATING;
        else next_state = IDLE;
      end
      ROTATING: next_state = COUNTING;
      COUNTING: begin
        if (rotation_count == n - 1) next_state = DONE;
        else next_state = ROTATING;
      end
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Rotation logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rotated_s <= 0;
      rotation_count <= 0;
    end else if (current_state == ROTATING) begin
      rotated_s <= {s[rotation_count - 1:0], s[7:rotation_count]};
    end
  end

  // Counting logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      temp_result <= 0;
    end else if (current_state == COUNTING) begin
      // XOR reduction for parity check
      parity_check = rotated_s;
      parity_check[0] = parity_check[0] ^ parity_check[1];
      parity_check[1] = parity_check[2] ^ parity_check[3];
      parity_check[2] = parity_check[4] ^ parity_check[5];
      parity_check[3] = parity_check[6] ^ parity_check[7];
      parity_check[0] = parity_check[0] ^ parity_check[1];
      parity_check[1] = parity_check[2] ^ parity_check[3];
      parity_check[0] = parity_check[0] ^ parity_check[1];

      if (parity_check[0]) begin
        temp_result <= temp_result + 1;
      end
      rotation_count <= rotation_count + 1;
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
    end else if (current_state == DONE) begin
      result <= temp_result;
      done <= 1;
    end else begin
      done <= 0;
    end
  end

endmodule