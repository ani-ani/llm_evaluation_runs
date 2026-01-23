module max_average_subarray (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [2:0] k,
  input [7:0] data_in,
  input [2:0] index,
  input write_en,
  output reg [15:0] result,
  output reg done,
  output reg valid
);

  // Internal registers
  reg [7:0] array [0:7];
  reg [2:0] state;
  reg [2:0] i, j;
  reg [15:0] current_sum;
  reg [15:0] current_avg;
  reg [15:0] max_avg;
  reg [2:0] current_length;
  reg [2:0] count;
  reg [7:0] divisor;
  reg [15:0] remainder;
  reg [15:0] quotient;
  reg [7:0] bit_pos;

  // State definitions
  localparam IDLE = 3'b000;
  localparam LOAD = 3'b001;
  localparam COMPUTE = 3'b010;
  localparam DIVIDE = 3'b011;
  localparam DONE = 3'b100;

  // Reset all registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 0;
      j <= 0;
      current_sum <= 0;
      current_avg <= 0;
      max_avg <= 0;
      current_length <= 0;
      count <= 0;
      divisor <= 0;
      remainder <= 0;
      quotient <= 0;
      bit_pos <= 0;
      result <= 0;
      done <= 0;
      valid <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD;
            i <= 0;
            j <= 0;
            current_sum <= 0;
            current_avg <= 0;
            max_avg <= 0;
            current_length <= 0;
            count <= 0;
            done <= 0;
            valid <= 0;
          end
        end
        LOAD: begin
          if (write_en) begin
            array[index] <= data_in;
            count <= count + 1;
            if (count == n) begin
              state <= COMPUTE;
              i <= 0;
              j <= 0;
              max_avg <= 0;
            end
          end
        end
        COMPUTE: begin
          if (j == 0) begin
            current_sum <= array[i];
            current_length <= 1;
          end else begin
            current_sum <= current_sum + array[i + j];
            current_length <= current_length + 1;
          end
          if (current_length >= k) begin
            state <= DIVIDE;
            divisor <= current_length;
            remainder <= current_sum << 8;
            quotient <= 0;
            bit_pos <= 8;
          end else if (i + j + 1 < n) begin
            j <= j + 1;
          end else if (i + 1 < n - k + 1) begin
            i <= i + 1;
            j <= 0;
          end else begin
            state <= DONE;
            result <= max_avg;
            done <= 1;
            valid <= 1;
          end
        end
        DIVIDE: begin
          if (bit_pos > 0) begin
            remainder <= remainder << 1;
            quotient <= quotient << 1;
            if (remainder[16]) begin
              remainder <= remainder - divisor;
              quotient[0] <= 1;
            end
            bit_pos <= bit_pos - 1;
          end else begin
            current_avg <= quotient;
            if (current_avg > max_avg) begin
              max_avg <= current_avg;
            end
            state <= COMPUTE;
            if (i + j + 1 < n) begin
              j <= j + 1;
            end else if (i + 1 < n - k + 1) begin
              i <= i + 1;
              j <= 0;
            end else begin
              state <= DONE;
              result <= max_avg;
              done <= 1;
              valid <= 1;
            end
          end
        end
        DONE: begin
          if (start) begin
            state <= LOAD;
            i <= 0;
            j <= 0;
            current_sum <= 0;
            current_avg <= 0;
            max_avg <= 0;
            current_length <= 0;
            count <= 0;
            done <= 0;
            valid <= 0;
          end
        end
      endcase
    end
  end

endmodule