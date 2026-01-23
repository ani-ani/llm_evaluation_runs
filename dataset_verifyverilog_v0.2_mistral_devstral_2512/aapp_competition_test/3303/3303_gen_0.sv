module carry_free_addition (
  input clk,
  input rst_n,
  input start,
  input [15:0] a,
  input [15:0] b,
  output reg [15:0] steps,
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
  reg [15:0] k;
  reg [15:0] a_minus_k, b_plus_k;
  reg [15:0] a_plus_k, b_minus_k;
  reg [3:0] digit_a, digit_b;
  reg [3:0] digit_pos;
  reg carry_detected;
  reg [15:0] temp_a, temp_b;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      steps <= 16'd0;
      done <= 1'b0;
      k <= 16'd0;
      digit_pos <= 4'd0;
      carry_detected <= 1'b0;
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
        if (carry_detected) begin
          if (k == 16'd65535) next_state = DONE;
        end else begin
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
      k <= 16'd0;
      digit_pos <= 4'd0;
      carry_detected <= 1'b0;
    end else if (current_state == PROCESSING) begin
      // Compute a-k and b+k
      a_minus_k <= (a >= k) ? (a - k) : (a + (16'd65536 - k));
      b_plus_k <= (b + k) % 16'd65536;
      
      // Compute a+k and b-k
      a_plus_k <= (a + k) % 16'd65536;
      b_minus_k <= (b >= k) ? (b - k) : (b + (16'd65536 - k));
      
      // Check both combinations for carry
      carry_detected <= 1'b1;
      
      // Check a-k + b+k
      temp_a = a_minus_k;
      temp_b = b_plus_k;
      for (int i = 0; i < 5; i++) begin
        digit_a = temp_a % 10;
        digit_b = temp_b % 10;
        if (digit_a + digit_b >= 10) begin
          carry_detected = 1'b1;
          break;
        end
        temp_a = temp_a / 10;
        temp_b = temp_b / 10;
      end
      
      if (carry_detected) begin
        // Check a+k + b-k
        temp_a = a_plus_k;
        temp_b = b_minus_k;
        carry_detected = 1'b0;
        for (int i = 0; i < 5; i++) begin
          digit_a = temp_a % 10;
          digit_b = temp_b % 10;
          if (digit_a + digit_b >= 10) begin
            carry_detected = 1'b1;
            break;
          end
          temp_a = temp_a / 10;
          temp_b = temp_b / 10;
        end
      end
      
      if (!carry_detected) begin
        steps <= k;
        done <= 1'b1;
      end else if (k == 16'd65535) begin
        steps <= 16'd65535;
        done <= 1'b1;
      end else begin
        k <= k + 1'b1;
      end
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
    end else if (current_state == DONE) begin
      done <= 1'b1;
    end else begin
      done <= 1'b0;
    end
  end

endmodule