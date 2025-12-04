module pirates_game_solver(
  input clk,
  input rst_n,
  input start,
  input [3:0] n_in,
  input [9:0] a [0:14],
  output reg [13:0] result,
  output reg done
);

reg [3:0] x_ptr;
reg [13:0] acc_sum;
reg [9:0] data_reg [0:14];
reg [1:0] state;
reg [3:0] cycle_count;
reg [3:0] n_stored;

localparam IDLE = 2'b00;
localparam PROCESSING = 2'b01;
localparam DONE = 2'b10;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 1'b0;
    result <= 14'b0;
    acc_sum <= 14'b0;
    x_ptr <= 4'b0;
    cycle_count <= 4'b0;
    n_stored <= 4'b0;
    foreach (data_reg[i]) data_reg[i] <= 10'b0;
  end else begin
    case (state)
      IDLE: begin
        done <= 1'b0;
        if (start) begin
          if (n_in <= 4'd1 || n_in[0] == 1'b0) begin
            result <= 14'h3FFF;
            done <= 1'b1;
            state <= DONE;
          end else begin
            foreach (data_reg[i]) data_reg[i] <= a[i];
            acc_sum <= 14'b0;
            x_ptr <= 4'd14;
            n_stored <= n_in;
            cycle_count <= 4'b0;
            state <= PROCESSING;
          end
        end
      end

      PROCESSING: begin
        if (cycle_count < 4'd14) begin
          if (x_ptr >= 4'd1 && x_ptr <= (n_stored - 4'd1)) begin
            automatic logic [9:0] left = data_reg[2*x_ptr];
            automatic logic [9:0] right = data_reg[2*x_ptr + 1];
            automatic logic [9:0] max_val = (left > right) ? left : right;
            data_reg[x_ptr] <= data_reg[x_ptr] - max_val;
            acc_sum <= acc_sum + max_val;
          end
          x_ptr <= x_ptr - 4'd1;
          cycle_count <= cycle_count + 4'd1;
        end else begin
          if (x_ptr >= 4'd1 && x_ptr <= (n_stored - 4'd1)) begin
            automatic logic [9:0] left = data_reg[2*x_ptr];
            automatic logic [9:0] right = data_reg[2*x_ptr + 1];
            automatic logic [9:0] max_val = (left > right) ? left : right;
            acc_sum <= acc_sum + max_val;
          end
          result <= acc_sum + data_reg[0];
          done <= 1'b1;
          state <= DONE;
        end
      end

      DONE: begin
        done <= 1'b0;
        state <= IDLE;
      end
    endcase
  end
end

endmodule