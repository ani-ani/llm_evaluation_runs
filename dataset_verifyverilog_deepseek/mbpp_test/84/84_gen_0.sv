module newman_conway(input clk, input rst_n, input start, input [3:0] n_in, output reg [3:0] result, output reg done);
  reg [3:0] p_array [1:16];
  reg [3:0] n_latched;
  reg [3:0] current_n;
  reg state; // 0: IDLE, 1: COMPUTE

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 4'b0;
      done <= 1'b0;
      state <= 1'b0;
      for (int i = 1; i <= 16; i=i+1) p_array[i] <= 4'b0;
    end else begin
      case (state)
        1'b0: begin // IDLE
          done <= 1'b0;
          if (start) begin
            n_latched <= n_in;
            if (n_in == 4'd1 || n_in == 4'd2) begin
              result <= 4'd1;
              done <= 1'b1;
            end else begin
              p_array[1] <= 4'd1;
              p_array[2] <= 4'd1;
              current_n <= 4'd3;
              state <= 1'b1;
            end
          end
        end
        1'b1: begin // COMPUTE
          if (current_n <= n_latched) begin
            p_array[current_n] <= p_array[p_array[current_n-4'd1]] + p_array[current_n - p_array[current_n-4'd1]];
            current_n <= current_n + 4'd1;
          end
          if (current_n > n_latched) begin
            result <= p_array[n_latched];
            done <= 1'b1;
            state <= 1'b0;
          end
        end
      endcase
    end
  end
endmodule