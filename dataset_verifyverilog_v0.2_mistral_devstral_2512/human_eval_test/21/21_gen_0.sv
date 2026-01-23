module rescale_to_unit (
  input clk,
  input rst_n,
  input start,
  input [15:0] data_in,
  input data_valid,
  input data_last,
  output reg [15:0] result,
  output reg result_valid,
  output reg done
);

  parameter MAX_N = 8;
  parameter Q_FORMAT = 16;

  typedef enum logic [2:0] {
    IDLE,
    COLLECT,
    COMPUTE,
    OUTPUT,
    DONE
  } state_t;

  state_t state, next_state;
  logic [15:0] data_buffer [0:MAX_N-1];
  logic [$clog2(MAX_N)-1:0] count;
  logic [$clog2(MAX_N)-1:0] output_idx;
  logic [15:0] min_val, max_val;
  logic [15:0] range;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      count <= 0;
      output_idx <= 0;
      min_val <= 16'hFFFF;
      max_val <= 16'h0000;
      result <= 16'h0000;
      result_valid <= 1'b0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      if (state == COLLECT && data_valid) begin
        data_buffer[count] <= data_in;
        if (data_in < min_val) min_val <= data_in;
        if (data_in > max_val) max_val <= data_in;
        if (data_last) begin
          count <= count + 1;
        end else if (data_valid) begin
          count <= count + 1;
        end
      end else if (state == OUTPUT) begin
        output_idx <= output_idx + 1;
      end
    end
  end

  always @(*) begin
    next_state = state;
    result_valid = 1'b0;
    done = 1'b0;
    case (state)
      IDLE: begin
        if (start) next_state = COLLECT;
      end
      COLLECT: begin
        if (data_last) next_state = COMPUTE;
      end
      COMPUTE: begin
        next_state = OUTPUT;
        output_idx = 0;
        range = (max_val == min_val) ? 16'h0001 : (max_val - min_val);
      end
      OUTPUT: begin
        if (output_idx == count - 1) begin
          next_state = DONE;
        end else begin
          next_state = OUTPUT;
        end
        result_valid = 1'b1;
        if (range == 0) begin
          result = 16'h0000;
        end else begin
          result = (data_buffer[output_idx] - min_val) << Q_FORMAT;
          result = result / range;
        end
      end
      DONE: begin
        done = 1'b1;
        if (!start) next_state = IDLE;
      end
    endcase
  end

endmodule