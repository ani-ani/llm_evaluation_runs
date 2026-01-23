module sweet_diet (
  input clk,
  input rst_n,
  input start,
  input [2:0] m,
  input [15:0] a [0:7],
  input [15:0] s [0:7],
  input [15:0] n,
  output reg [15:0] additional_count,
  output reg forever_flag,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CHECK_BALANCE,
    UPDATE_COUNT,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [15:0] count;
  reg [15:0] step;
  reg [15:0] new_n;
  reg [15:0] new_s [0:7];
  reg [31:0] f [0:7];
  reg [31:0] sum_a;
  reg [15:0] i;
  reg valid_type;

  // Compute sum of a
  always @(*) begin
    sum_a = 0;
    for (int j = 0; j < 8; j++) begin
      if (j < m) sum_a = sum_a + a[j];
    end
  end

  // Compute fixed-point fractions
  always @(*) begin
    for (int j = 0; j < 8; j++) begin
      if (j < m) f[j] = (a[j] * 65536) / sum_a;
      else f[j] = 0;
    end
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      count <= 0;
      step <= 0;
      additional_count <= 0;
      forever_flag <= 0;
      done <= 0;
      i <= 0;
      valid_type <= 0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          if (start) begin
            count <= 0;
            step <= 0;
            additional_count <= 0;
            forever_flag <= 0;
            done <= 0;
            i <= 0;
            valid_type <= 0;
          end
        end

        CHECK_BALANCE: begin
          if (i == 0) begin
            new_n = n + count + 1;
            for (int j = 0; j < 8; j++) begin
              if (j < m) new_s[j] = s[j] + (j == i ? 1 : 0);
            end
          end

          if (i < m) begin
            // Check balance condition
            reg [31:0] lower_bound = (new_n * f[i]) - 65536;
            reg [31:0] upper_bound = (new_n * f[i]) + 65536;
            reg [31:0] scaled_s = new_s[i] << 16;

            if (scaled_s > lower_bound && scaled_s < upper_bound) begin
              valid_type <= 1;
            end
          end
        end

        UPDATE_COUNT: begin
          if (valid_type) begin
            count <= count + 1;
            if (count == 255) begin
              forever_flag <= 1;
              done <= 1;
            end
          end
          valid_type <= 0;
        end

        DONE: begin
          additional_count <= count;
          done <= 1;
        end

        default: current_state <= IDLE;
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = CHECK_BALANCE;
      end

      CHECK_BALANCE: begin
        if (i < m - 1) begin
          next_state = CHECK_BALANCE;
        end else if (valid_type) begin
          next_state = UPDATE_COUNT;
        end else if (count == 255) begin
          next_state = DONE;
        end else begin
          next_state = DONE;
        end
      end

      UPDATE_COUNT: begin
        if (count == 255 || !valid_type) begin
          next_state = DONE;
        end else begin
          next_state = CHECK_BALANCE;
        end
      end

      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Increment i in CHECK_BALANCE state
  always @(posedge clk) begin
    if (current_state == CHECK_BALANCE && i < m - 1) begin
      i <= i + 1;
    end else if (current_state == UPDATE_COUNT || current_state == CHECK_BALANCE) begin
      i <= 0;
    end
  end

endmodule