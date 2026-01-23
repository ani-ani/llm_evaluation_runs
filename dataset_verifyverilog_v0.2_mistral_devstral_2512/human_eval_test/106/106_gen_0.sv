module factorial_sum_sequence (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  output reg [31:0] result,
  output reg [2:0] index,
  output reg valid,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    SETUP,
    CALCULATE,
    OUTPUT,
    DONE
  } state_t;

  state_t state;
  reg [2:0] current_index;
  reg [31:0] temp_result;
  reg [31:0] counter;
  reg [31:0] accumulator;
  reg [2:0] num_elements;
  reg is_even;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_index <= 0;
      temp_result <= 0;
      counter <= 0;
      accumulator <= 0;
      num_elements <= 0;
      is_even <= 0;
      result <= 0;
      index <= 0;
      valid <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SETUP;
            num_elements <= n;
            current_index <= 0;
            done <= 0;
          end
        end

        SETUP: begin
          state <= CALCULATE;
          is_even <= (current_index + 1) % 2 == 0;
          if (is_even) begin
            accumulator <= 1;
            counter <= 1;
          end else begin
            accumulator <= 0;
            counter <= 1;
          end
        end

        CALCULATE: begin
          if (is_even) begin
            // Factorial calculation
            if (counter <= current_index + 1) begin
              accumulator <= accumulator * counter;
              counter <= counter + 1;
            end else begin
              temp_result <= accumulator;
              state <= OUTPUT;
            end
          end else begin
            // Sum calculation
            if (counter <= current_index + 1) begin
              accumulator <= accumulator + counter;
              counter <= counter + 1;
            end else begin
              temp_result <= accumulator;
              state <= OUTPUT;
            end
          end
        end

        OUTPUT: begin
          result <= temp_result;
          index <= current_index;
          valid <= 1;
          state <= SETUP;
          current_index <= current_index + 1;
          if (current_index == num_elements - 1) begin
            state <= DONE;
          end
        end

        DONE: begin
          valid <= 0;
          done <= 1;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule