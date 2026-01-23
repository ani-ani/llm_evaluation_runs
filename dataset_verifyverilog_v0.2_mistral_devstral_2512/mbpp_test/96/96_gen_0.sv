module divisor_counter(
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  output reg [7:0] divisor_count,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t state;
  reg [7:0] counter;
  reg [7:0] temp_n;
  reg [7:0] remainder;

  // Reset state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      divisor_count <= 8'b0;
      done <= 1'b0;
      counter <= 8'b0;
      temp_n <= 8'b0;
      remainder <= 8'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESSING;
            divisor_count <= 8'b0;
            done <= 1'b0;
            counter <= 1;
            temp_n <= n;
            remainder <= 8'b0;
          end
        end
        PROCESSING: begin
          // Check if counter divides n
          if (counter == 1) begin
            // 1 always divides n
            divisor_count <= divisor_count + 1;
          end else if (counter == n) begin
            // n always divides itself
            divisor_count <= divisor_count + 1;
            state <= DONE;
            done <= 1'b1;
          end else begin
            // Compute n % counter using repeated subtraction
            remainder <= temp_n;
            while (remainder >= counter) begin
              remainder <= remainder - counter;
            end
            if (remainder == 0) begin
              divisor_count <= divisor_count + 1;
            end
            counter <= counter + 1;
          end
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 1'b0;
          end
        end
      endcase
    end
  end

endmodule