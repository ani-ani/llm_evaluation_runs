module dynamic_max_sum(
  input clk,
  input rst_n,
  input start,
  input [4:0] n_in,
  output reg [15:0] result,
  output reg done
);

  localparam IDLE = 2'b00;
  localparam COMPUTE = 2'b01;
  localparam DONE = 2'b10;

  reg [1:0] state, next_state;
  reg [4:0] i, n_capture;
  reg [15:0] f_mem [0:31];
  reg [15:0] result_next;
  reg [4:0] i_next, n_capture_next;
  reg done_next;

  // Sequential block
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 5'd0;
      n_capture <= 5'd0;
      result <= 16'd0;
      done <= 1'b0;
      f_mem[0] <= 16'd0;
      f_mem[1] <= 16'd1;
      for (int k=2; k<32; k++) f_mem[k] <= 16'd0;
    end
    else begin
      state <= next_state;
      i <= i_next;
      n_capture <= n_capture_next;
      result <= result_next;
      done <= done_next;
      if (state == COMPUTE) begin
        int temp_val;
        temp_val = f_mem[i/2] + f_mem[i/3] + f_mem[i/4] + f_mem[i/5];
        if (temp_val > i) 
          f_mem[i] <= temp_val;
        else
          f_mem[i] <= i;
      end
    end
  end

  // Combinational block for next state and other signals
  always_comb begin
    next_state = state;
    i_next = i;
    n_capture_next = n_capture;
    result_next = result; // default: leave unchanged
    done_next = 1'b0;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = COMPUTE;
          n_capture_next = n_in;
          i_next = 5'd2;
        end
      end
      COMPUTE: begin
        i_next = i + 1;
        if (i == n_capture) begin
          int temp_val;
          temp_val = f_mem[i/2] + f_mem[i/3] + f_mem[i/4] + f_mem[i/5];
          result_next = (temp_val > i) ? temp_val : i;
          next_state = DONE;
        end
      end
      DONE: begin
        next_state = IDLE;
        done_next = 1'b1;
      end
    endcase
  end

endmodule