module make_a_pile (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  output reg [7:0] result_data,
  output reg [3:0] result_index,
  output reg result_valid,
  output reg done
);

  // State definitions
  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] PROCESSING = 2'b01;
  localparam [1:0] DONE = 2'b10;

  reg [1:0] state;
  reg [3:0] current_level;
  reg [7:0] current_stones;
  reg parity;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset state
      state <= IDLE;
      current_level <= 0;
      current_stones <= 0;
      result_data <= 0;
      result_index <= 0;
      result_valid <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            if (n == 0) begin
              state <= DONE;
              done <= 1;
            end else begin
              state <= PROCESSING;
              current_level <= 0;
              current_stones <= n;
              parity <= n[0]; // Store LSB for parity
              result_data <= n;
              result_index <= 1;
              result_valid <= 1;
              done <= 0;
            end
          end
        end
        PROCESSING: begin
          result_valid <= 1;
          done <= 0;
          if (current_level < n - 1) begin
            current_level <= current_level + 1;
            current_stones <= current_stones + 2;
            result_data <= current_stones + 2;
            result_index <= current_level + 2;
          end else begin
            state <= DONE;
            done <= 1;
            result_valid <= 0;
          end
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule