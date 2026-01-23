module array_reconstructor #(
  parameter N = 16,
  parameter Q_W = 5,
  parameter MAX_STACK = 8
)(
  input clk,
  input rst_n,
  input start,
  input [4:0] data_in,
  input valid_in,
  output reg [4:0] result_out,
  output reg valid_out,
  output reg done,
  output reg error
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    READ_SCAN,
    PROCESS,
    DONE
  } state_t;

  state_t state;
  reg [3:0] index;
  reg [4:0] current_max;
  reg [4:0] current_val;
  reg [4:0] stack[MAX_STACK];
  reg [2:0] stack_ptr;
  reg [4:0] last_occurrence[32];
  reg [4:0] global_max_seen;
  reg zero_exists;
  reg [4:0] q_value;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      index <= 0;
      current_max <= 0;
      current_val <= 0;
      stack_ptr <= 0;
      for (int i = 0; i < MAX_STACK; i++) stack[i] <= 0;
      for (int i = 0; i < 32; i++) last_occurrence[i] <= 0;
      global_max_seen <= 0;
      zero_exists <= 0;
      q_value <= 0;
      result_out <= 0;
      valid_out <= 0;
      done <= 0;
      error <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= READ_SCAN;
            index <= N-1;
            current_max <= 0;
            current_val <= 0;
            stack_ptr <= 0;
            for (int i = 0; i < MAX_STACK; i++) stack[i] <= 0;
            for (int i = 0; i < 32; i++) last_occurrence[i] <= 0;
            global_max_seen <= 0;
            zero_exists <= 0;
            q_value <= 0;
            result_out <= 0;
            valid_out <= 0;
            done <= 0;
            error <= 0;
          end
        end
        READ_SCAN: begin
          if (valid_in) begin
            if (data_in != 0) begin
              last_occurrence[data_in] <= index;
              if (data_in > global_max_seen) global_max_seen <= data_in;
            end else begin
              zero_exists <= 1;
            end
            if (index == 0) begin
              state <= PROCESS;
              index <= N-1;
              current_max <= 0;
              stack_ptr <= 0;
              q_value <= (zero_exists && (32 > global_max_seen)) ? 32 : 0;
            end else begin
              index <= index - 1;
            end
          end
        end
        PROCESS: begin
          if (valid_in) begin
            if (data_in == 0) begin
              current_val <= (current_max > 0) ? current_max : (q_value > 0) ? q_value : 1;
              if (q_value > 0) q_value <= 0;
            end else begin
              if (data_in > current_max) begin
                if (stack_ptr < MAX_STACK) begin
                  stack[stack_ptr] <= current_max;
                  stack_ptr <= stack_ptr + 1;
                end else begin
                  error <= 1;
                end
                current_max <= data_in;
                current_val <= data_in;
              end else if (data_in < current_max) begin
                error <= 1;
                current_val <= data_in;
              end else begin
                current_val <= data_in;
                if (stack_ptr > 0 && last_occurrence[current_max] == index) begin
                  stack_ptr <= stack_ptr - 1;
                  current_max <= stack[stack_ptr];
                end
              end
            end
            result_out <= current_val;
            valid_out <= 1;
            if (index == 0) begin
              state <= DONE;
              done <= 1;
            end else begin
              index <= index - 1;
            end
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