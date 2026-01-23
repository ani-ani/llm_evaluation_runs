module bitstring_constructor (
  input clk,
  input rst_n,
  input start,
  input [31:0] a,
  input [31:0] b,
  input [31:0] c,
  input [31:0] d,
  output reg [7:0] result_string,
  output reg [2:0] result_length,
  output reg done,
  output reg valid
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    CHECK_PARAMS,
    SOLVE_KL,
    CONSTRUCT,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [31:0] k, l;
  reg [31:0] counter;
  reg [7:0] temp_string;
  reg [2:0] temp_length;
  reg k_valid, l_valid, params_valid;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result_string <= 0;
      result_length <= 0;
      done <= 0;
      valid <= 0;
      counter <= 0;
      k <= 0;
      l <= 0;
      temp_string <= 0;
      temp_length <= 0;
      k_valid <= 0;
      l_valid <= 0;
      params_valid <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = CHECK_PARAMS;
      end
      CHECK_PARAMS: begin
        next_state = SOLVE_KL;
      end
      SOLVE_KL: begin
        next_state = CONSTRUCT;
      end
      CONSTRUCT: begin
        if (counter == 99) next_state = DONE;
        else next_state = CONSTRUCT;
      end
      DONE: begin
        if (start) next_state = CHECK_PARAMS;
      end
      default: next_state = IDLE;
    endcase
  end

  // State actions
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset handled in state register
    end else begin
      case (current_state)
        IDLE: begin
          done <= 0;
          valid <= 0;
        end
        CHECK_PARAMS: begin
          // Check if b == c
          params_valid = (b == c);
          // Special case: all zeros
          if (a == 0 && b == 0 && c == 0 && d == 0) begin
            k_valid = 1;
            l_valid = 1;
            k = 0;
            l = 0;
          end
          // Special case: all ones
          else if (a == 0 && b == 0 && c == 0 && d == 1) begin
            k_valid = 1;
            l_valid = 1;
            k = 0;
            l = 1;
          end
        end
        SOLVE_KL: begin
          // Solve for k and l
          if (params_valid) begin
            // Solve k from a = k*(k-1)/2
            if (a == 0) begin
              k = 0;
              k_valid = 1;
            end else begin
              k = 0;
              for (int i = 1; i <= 8; i = i + 1) begin
                if (i*(i-1)/2 == a) begin
                  k = i;
                  k_valid = 1;
                end
              end
            end
            // Solve l from d = l*(l-1)/2
            if (d == 0) begin
              l = 0;
              l_valid = 1;
            end else begin
              l = 0;
              for (int i = 1; i <= 8; i = i + 1) begin
                if (i*(i-1)/2 == d) begin
                  l = i;
                  l_valid = 1;
                end
              end
            end
            // Verify b = k*l
            if (k_valid && l_valid && (k*l == b)) begin
              params_valid = 1;
            end else begin
              params_valid = 0;
            end
          end
        end
        CONSTRUCT: begin
          if (counter == 0) begin
            temp_string = 0;
            temp_length = 0;
            if (params_valid && k_valid && l_valid) begin
              // Construct string
              if (k + l > 8) begin
                valid = 0;
              end else begin
                valid = 1;
                temp_length = k + l;
                // Construction logic
                if (b >= k && (b - k) % (k - 1) == 0 && k > 1) begin
                  // Pattern: (k-1) zeros, then '0', then l ones
                  for (int i = 0; i < k-1; i = i + 1) begin
                    temp_string[i] = 0;
                  end
                  temp_string[k-1] = 0;
                  for (int i = 0; i < l; i = i + 1) begin
                    temp_string[k + i] = 1;
                  end
                end else if (c >= k && (c - k) % (l - 1) == 0 && l > 1) begin
                  // Pattern: '1', then k zeros, then (l-1) ones
                  temp_string[0] = 1;
                  for (int i = 0; i < k; i = i + 1) begin
                    temp_string[1 + i] = 0;
                  end
                  for (int i = 0; i < l-1; i = i + 1) begin
                    temp_string[1 + k + i] = 1;
                  end
                end else if (b == 0 && c == 0) begin
                  // All zeros then all ones
                  for (int i = 0; i < k; i = i + 1) begin
                    temp_string[i] = 0;
                  end
                  for (int i = 0; i < l; i = i + 1) begin
                    temp_string[k + i] = 1;
                  end
                end else begin
                  valid = 0;
                end
              end
            end else begin
              valid = 0;
            end
          end
          counter = counter + 1;
          if (counter == 99) begin
            result_string = temp_string;
            result_length = temp_length;
            done = 1;
          end
        end
        DONE: begin
          done = 1;
        end
      endcase
    end
  end

endmodule