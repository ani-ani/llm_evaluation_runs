module beautiful_number(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [2:0] k,
  input [3:0] digits [0:7],
  output reg [3:0] y_digits [0:7],
  output reg done
);
  typedef enum logic [2:0] {
    IDLE,
    LOAD,
    COMPARE_GEN,
    COMPARE_CMP,
    INCREMENT_ADD,
    INCREMENT_OVF,
    GENERATE
  } state_t;

  state_t current_state, next_state;
  reg [2:0] n_val, k_val;
  reg [3:0] original_digits [0:7];
  reg [3:0] prefix [0:7];
  reg [3:0] gen_pattern [0:7];
  reg comparison_greater, comparison_equal;
  reg inc_carry;
  reg carry;
  integer i, idx;

  // State register and main logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      for (i = 0; i < 8; i++) begin
        original_digits[i] <= 4'd0;
        prefix[i] <= 4'd0;
        gen_pattern[i] <= 4'd0;
        y_digits[i] <= 4'd0;
      end
      n_val <= 0;
      k_val <= 0;
      comparison_greater <= 0;
      comparison_equal <= 0;
      inc_carry <= 0;
    end else begin
      current_state <= next_state;
      done <= 0;

      case (current_state)
        IDLE: begin
          if (start) next_state = LOAD;
        end

        LOAD: begin
          for (i = 0; i < 8; i++) original_digits[i] <= digits[i];
          for (i = 0; i < 8; i++) prefix[i] <= (i < k) ? digits[i] : 4'd0;
          n_val <= n;
          k_val <= (k == 0) ? 1 : k; // Guard against k=0
          next_state = COMPARE_GEN;
        end

        COMPARE_GEN: begin
          for (i = 0; i < 8; i++) begin
            if (i < n_val) gen_pattern[i] <= prefix[i % k_val];
            else gen_pattern[i] <= 4'd0;
          end
          next_state = COMPARE_CMP;
        end

        COMPARE_CMP: begin
          comparison_greater <= 0;
          comparison_equal <= 1;
          idx = 0;
          while (idx < n_val) begin
            if (gen_pattern[idx] > original_digits[idx]) begin
              comparison_greater <= 1;
              comparison_equal <= 0;
              idx = n_val;
            end else if (gen_pattern[idx] < original_digits[idx]) begin
              comparison_greater <= 0;
              comparison_equal <= 0;
              idx = n_val;
            end else begin
              idx = idx + 1;
            end
          end
          if (comparison_greater || comparison_equal) next_state = GENERATE;
          else next_state = INCREMENT_ADD;
        end

        INCREMENT_ADD: begin
          carry <= 1;
          for (i = k_val-1; i >= 0; i = i-1) begin
            if (carry) begin
              if (prefix[i] == 4'd9) begin
                prefix[i] <= 4'd0;
                carry <= 1;
              end else begin
                prefix[i] <= prefix[i] + 4'd1;
                carry <= 0;
              end
            end
          end
          next_state = INCREMENT_OVF;
        end

        INCREMENT_OVF: begin
          if (carry) begin
            for (i = 0; i < k_val; i++) prefix[i] <= 4'd9;
          end
          next_state = GENERATE;
        end

        GENERATE: begin
          for (i = 0; i < 8; i++) y_digits[i] <= (i < n_val) ? prefix[i % k_val] : 4'd0;
          done <= 1;
          next_state = IDLE;
        end

        default: next_state = IDLE;
      endcase
    end
  end

  // Next state logic (combinational)
  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: if (start) next_state = LOAD;
      LOAD: next_state = COMPARE_GEN;
      COMPARE_GEN: next_state = COMPARE_CMP;
      COMPARE_CMP: if (comparison_greater || comparison_equal) next_state = GENERATE;
                   else next_state = INCREMENT_ADD;
      INCREMENT_ADD: next_state = INCREMENT_OVF;
      INCREMENT_OVF: next_state = GENERATE;
      GENERATE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

endmodule