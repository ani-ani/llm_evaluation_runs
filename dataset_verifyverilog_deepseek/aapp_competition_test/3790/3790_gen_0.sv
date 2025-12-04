module longest_non_decreasing(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [3:0] T,
  input [8:0] a [0:7],
  output reg [7:0] result,
  output reg done
);

  reg [3:0] T_ext;
  reg [7:0] total_elements;
  reg [15:0] cycle_counter;
  reg [7:0] i, j;
  reg [8:0] buffer_i;
  reg [7:0] max_count [0:127];
  reg [7:0] global_max;
  reg [7:0] current_max;

  localparam [1:0] IDLE = 2'd0,
                   INIT = 2'd1,
                   COMPUTE = 2'd2,
                   DONE = 2'd3;

  reg [1:0] state;

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      global_max <= 0;
      for (int idx=0; idx<128; idx++) max_count[idx] <= 0;
      cycle_counter <= 0;
      i <= 0;
      current_max <= 0;
    end else begin
      done <= 0;
      case(state)
        IDLE: begin
          if (start) begin
            T_ext <= (T > 16) ? 16 : T;
            total_elements <= T_ext * n;
            cycle_counter <= 0;
            state <= INIT;
          end
        end

        INIT: begin
          global_max <= 0;
          for (int idx=0; idx<128; idx++) max_count[idx] <= 0;
          i <= 0;
          cycle_counter <= 0;
          state <= COMPUTE;
        end

        COMPUTE: begin
          cycle_counter <= cycle_counter + 1;
          if (i < total_elements) begin
            buffer_i = a[i % n];
            current_max = 0;
            for (j = 0; j < i; j = j + 1) begin
              if (a[j % n] <= buffer_i && max_count[j] > current_max)
                current_max = max_count[j];
            end
            max_count[i] <= current_max + 1;
            if ((current_max + 1) > global_max)
              global_max <= current_max + 1;
            i <= i + 1;
          end
          if (cycle_counter == (9 * total_elements + 1)) begin
            result <= global_max;
            done <= 1;
            state <= DONE;
          end
        end

        DONE: begin
          state <= IDLE;
        end
      endcase
    end
  end
endmodule