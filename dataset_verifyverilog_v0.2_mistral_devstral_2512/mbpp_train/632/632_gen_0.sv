module move_zero (
  input clk,
  input rst_n,
  input start,
  input [3:0] num_elements,
  input [15:0] input_array [15:0],
  output reg [15:0] output_array [15:0],
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    PASS1_COUNT,
    PASS1_EXTRACT,
    PASS2_FILL,
    DONE
  } state_t;

  state_t state = IDLE;
  reg [3:0] count = 0;  // Count of non-zero elements
  reg [3:0] index = 0;  // Current index for processing
  reg [3:0] cycle_count = 0;  // Cycle counter for latency

  // Buffer to store non-zero elements
  reg [15:0] buffer [15:0];

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      count <= 0;
      index <= 0;
      cycle_count <= 0;
      done <= 0;
      for (int i = 0; i < 16; i++) begin
        output_array[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PASS1_COUNT;
            count <= 0;
            index <= 0;
            cycle_count <= 0;
            done <= 0;
          end
        end

        PASS1_COUNT: begin
          if (index < num_elements) begin
            if (input_array[index] != 0) begin
              buffer[count] <= input_array[index];
              count <= count + 1;
            end
            index <= index + 1;
            cycle_count <= cycle_count + 1;
            if (cycle_count == 16) begin
              state <= PASS1_EXTRACT;
              index <= 0;
              cycle_count <= 0;
            end
          end else begin
            state <= PASS1_EXTRACT;
            index <= 0;
            cycle_count <= 0;
          end
        end

        PASS1_EXTRACT: begin
          if (index < count) begin
            output_array[index] <= buffer[index];
            index <= index + 1;
            cycle_count <= cycle_count + 1;
            if (cycle_count == 16) begin
              state <= PASS2_FILL;
              index <= count;
              cycle_count <= 0;
            end
          end else begin
            state <= PASS2_FILL;
            index <= count;
            cycle_count <= 0;
          end
        end

        PASS2_FILL: begin
          if (index < num_elements) begin
            output_array[index] <= 0;
            index <= index + 1;
            cycle_count <= cycle_count + 1;
            if (cycle_count == 4) begin
              state <= DONE;
              cycle_count <= 0;
            end
          end else begin
            state <= DONE;
            cycle_count <= 0;
          end
        end

        DONE: begin
          done <= 1;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end

        default: begin
          state <= IDLE;
          done <= 0;
        end
      endcase
    end
  end

endmodule