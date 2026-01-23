module dial_game (
  input clk,
  input rst_n,
  input start,
  input [3:0] A,
  input [3:0] B,
  input load,
  input [2:0] load_addr,
  input [3:0] load_data,
  output reg [7:0] sum_out,
  output reg done
);

  parameter N = 8;
  parameter IDLE = 3'b001;
  parameter SUMMING = 3'b010;
  parameter UPDATING = 3'b100;
  parameter DONE = 3'b000;

  reg [2:0] state;
  reg [3:0] dials [0:N-1];
  reg [7:0] sum_reg;
  reg [2:0] current_index;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      sum_reg <= 8'b0;
      current_index <= 3'b0;
      done <= 1'b0;
      for (int i = 0; i < N; i = i + 1) begin
        dials[i] <= 4'b0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (load) begin
            dials[load_addr] <= load_data;
          end
          if (start) begin
            state <= SUMMING;
            sum_reg <= 8'b0;
            current_index <= A - 1;
          end
        end
        SUMMING: begin
          if (current_index <= B - 1) begin
            sum_reg <= sum_reg + dials[current_index];
            current_index <= current_index + 1;
          end else begin
            state <= UPDATING;
            current_index <= A - 1;
          end
        end
        UPDATING: begin
          if (current_index <= B - 1) begin
            dials[current_index] <= (dials[current_index] + 1) % 10;
            current_index <= current_index + 1;
          end else begin
            state <= DONE;
          end
        end
        DONE: begin
          done <= 1'b1;
          state <= IDLE;
        end
        default: state <= IDLE;
      endcase
    end
  end

  assign sum_out = sum_reg;

endmodule