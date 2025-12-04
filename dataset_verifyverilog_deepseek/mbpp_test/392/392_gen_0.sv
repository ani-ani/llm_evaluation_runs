module dynamic_max_sum (input clk, input rst_n, input start, input [4:0] n_in, output reg [15:0] result, output reg done);
  typedef enum logic [1:0] {IDLE, COMPUTE, DONE} state_t;
  state_t state;
  reg [4:0] n_in_reg;
  reg [4:0] counter;
  reg [15:0] f_mem [0:31];
  wire [4:0] div2, div3, div4, div5;
  wire [15:0] sum;
  
  assign div2 = counter / 2;
  assign div3 = counter / 3;
  assign div4 = counter / 4;
  assign div5 = counter / 5;
  assign sum = f_mem[div2] + f_mem[div3] + f_mem[div4] + f_mem[div5];
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result <= 16'd0;
      counter <= 5'd0;
      n_in_reg <= 5'd0;
      for (int i=0; i<32; i++) begin
        if (i == 0) f_mem[i] <= 16'd0;
        else if (i == 1) f_mem[i] <= 16'd1;
        else f_mem[i] <= 16'd0;
      end
    end else begin
      case(state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            state <= COMPUTE;
            n_in_reg <= n_in;
            counter <= 5'd2;
          end
        end
        COMPUTE: begin
          if (counter <= n_in_reg) begin
            f_mem[counter] <= (sum > counter) ? sum : counter;
            if (counter == n_in_reg) result <= (sum > counter) ? sum : counter;
            counter <= counter + 1;
          end
          if (counter >= n_in_reg) state <= DONE;
          else state <= COMPUTE;
        end
        DONE: begin
          done <= 1'b1;
          state <= IDLE;
        end
        default: state <= IDLE;
      endcase
    end
  end
endmodule