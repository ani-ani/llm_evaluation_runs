module weather_prediction (
  input clk,
  input rst_n,
  input start,
  input signed [15:0] temp_in,
  input [6:0] n,
  output reg signed [15:0] prediction,
  output reg done,
  output reg valid
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    LOAD,
    CHECK,
    COMPUTE,
    DONE
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg signed [15:0] temp_reg [0:99]; // Store up to 100 temperatures
  reg [6:0] count; // Counter for number of temperatures received
  reg signed [15:0] common_diff; // Common difference for arithmetic progression
  reg is_arithmetic; // Flag indicating if sequence is arithmetic
  reg [6:0] delay_count; // Counter for delay cycles

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      count <= 0;
      is_arithmetic <= 1'b1;
      delay_count <= 0;
      done <= 1'b0;
      valid <= 1'b0;
      prediction <= 16'b0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = LOAD;
      end
      LOAD: begin
        if (count == n - 1) next_state = CHECK;
      end
      CHECK: begin
        if (count == n - 1) next_state = COMPUTE;
      end
      COMPUTE: begin
        if (delay_count == 3) next_state = DONE;
      end
      DONE: begin
        if (start) next_state = LOAD;
      end
      default: next_state = IDLE;
    endcase
  end

  // Data processing logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count <= 0;
      is_arithmetic <= 1'b1;
      delay_count <= 0;
      done <= 1'b0;
      valid <= 1'b0;
      prediction <= 16'b0;
    end else begin
      case (state)
        IDLE: begin
          count <= 0;
          is_arithmetic <= 1'b1;
          done <= 1'b0;
          valid <= 1'b0;
        end
        LOAD: begin
          if (count < n) begin
            temp_reg[count] <= temp_in;
            count <= count + 1;
            if (count == 2) begin
              common_diff <= temp_reg[1] - temp_reg[0];
            end
          end
        end
        CHECK: begin
          if (count < n) begin
            if (count > 1) begin
              if (temp_reg[count] - temp_reg[count - 1] != common_diff) begin
                is_arithmetic <= 1'b0;
              end
            end
            count <= count + 1;
          end
        end
        COMPUTE: begin
          if (delay_count < 3) begin
            delay_count <= delay_count + 1;
          end else begin
            if (is_arithmetic) begin
              prediction <= temp_reg[n - 1] + common_diff;
            end else begin
              prediction <= temp_reg[n - 1];
            end
            done <= 1'b1;
            valid <= 1'b1;
          end
        end
        DONE: begin
          done <= 1'b1;
          valid <= 1'b1;
        end
        default: begin
          count <= 0;
          is_arithmetic <= 1'b1;
          delay_count <= 0;
          done <= 1'b0;
          valid <= 1'b0;
        end
      endcase
    end
  end

endmodule