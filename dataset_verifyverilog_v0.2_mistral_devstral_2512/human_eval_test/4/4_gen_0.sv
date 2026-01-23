module mean_absolute_deviation (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_elements,
  input [31:0] data_in,
  input data_valid,
  output reg [31:0] result,
  output reg done,
  output reg [2:0] read_index
);

  parameter N = 8;
  parameter IDLE = 3'b000;
  parameter READ_MEAN = 3'b001;
  parameter READ_DATA = 3'b010;
  parameter COMPUTE = 3'b011;
  parameter DIVIDE = 3'b100;
  parameter DONE = 3'b101;

  reg [2:0] state = IDLE;
  reg [31:0] sum_mean = 0;
  reg [31:0] mean = 0;
  reg [31:0] sum_deviations = 0;
  reg [2:0] current_index = 0;
  reg [31:0] current_value = 0;
  reg [31:0] abs_diff = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      sum_mean <= 0;
      mean <= 0;
      sum_deviations <= 0;
      current_index <= 0;
      current_value <= 0;
      abs_diff <= 0;
      result <= 0;
      done <= 0;
      read_index <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= READ_MEAN;
            sum_mean <= 0;
            current_index <= 0;
            read_index <= 0;
          end
        end
        READ_MEAN: begin
          if (data_valid) begin
            sum_mean <= sum_mean + data_in;
            current_index <= current_index + 1;
            if (current_index == num_elements - 1) begin
              mean <= sum_mean >> 3; // Divide by 8 (2^3)
              state <= READ_DATA;
              current_index <= 0;
              read_index <= 0;
            end else begin
              read_index <= current_index + 1;
            end
          end
        end
        READ_DATA: begin
          if (data_valid) begin
            current_value <= data_in;
            if (current_value > mean) begin
              abs_diff <= current_value - mean;
            end else begin
              abs_diff <= mean - current_value;
            end
            sum_deviations <= sum_deviations + abs_diff;
            current_index <= current_index + 1;
            if (current_index == num_elements - 1) begin
              state <= COMPUTE;
            end else begin
              read_index <= current_index + 1;
            end
          end
        end
        COMPUTE: begin
          state <= DIVIDE;
        end
        DIVIDE: begin
          result <= sum_deviations >> 3; // Divide by 8 (2^3)
          state <= DONE;
        end
        DONE: begin
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