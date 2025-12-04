module trade_matcher(
  input clk,
  input rst_n,
  input start,
  input [3:0] i,
  input [3:0] j,
  output reg [3:0] max_length,
  output reg done
);

  // Character storage
  reg [7:0] s[0:15];
  initial begin
    s[0] = "A"; s[1] = "B"; s[2] = "A"; s[3] = "B"; s[4] = "A"; s[5] = "B"; s[6] = "c"; s[7] = "A";
    s[8] = "B"; s[9] = "A"; s[10] = "B"; s[11] = "A"; s[12] = "b"; s[13] = "A"; s[14] = "b"; s[15] = "a";
  end

  // State machine
  typedef enum logic [1:0] {IDLE, COMPARE, DONE} state_t;
  state_t current_state, next_state;

  // Internal signals
  reg [3:0] k_counter;
  reg [3:0] current_length;
  reg compare_en;
  reg [3:0] saved_i, saved_j;

  // Next state logic
  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start)
          next_state = COMPARE;
      end
      COMPARE: begin
        if (!compare_en || k_counter >= 15)
          next_state = DONE;
      end
      DONE: begin
        if (!start)
          next_state = IDLE;
      end
    endcase
  end

  // State register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      current_state <= IDLE;
    else
      current_state <= next_state;
  end

  // Counter and control logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      k_counter <= 4'd0;
      current_length <= 4'd0;
      compare_en <= 1'b0;
      saved_i <= 4'd0;
      saved_j <= 4'd0;
    end else begin
      case (current_state)
        IDLE: begin
          if (start) begin
            saved_i <= i;
            saved_j <= j;
            k_counter <= 4'd0;
            current_length <= 4'd0;
            compare_en <= 1'b1;
          end
        end
        COMPARE: begin
          if (compare_en) begin
            // Check if we can compare (no wrap-around)
            if (k_counter < 16) begin
              // Compare current characters
              if (s[saved_i + k_counter] == s[saved_j + k_counter]) begin
                k_counter <= k_counter + 1;
                current_length <= current_length + 1;
              end else begin
                compare_en <= 1'b0;
              end
            end else begin
              compare_en <= 1'b0;
            end
          end
        end
        DONE: begin
          if (!start) begin
            compare_en <= 1'b0;
            k_counter <= 4'd0;
            current_length <= 4'd0;
          end
        end
      endcase
    end
  end

  // Output logic with 2-cycle latency
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      max_length <= 4'd0;
      done <= 1'b0;
    end else begin
      case (current_state)
        COMPARE: begin
          // Pipeline result: valid after 2 cycles
          if (k_counter >= 2) begin
            max_length <= current_length - 2;
            done <= 1'b0;
          end
        end
        DONE: begin
          max_length <= current_length;
          done <= 1'b1;
        end
        default: begin
          max_length <= 4'd0;
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule