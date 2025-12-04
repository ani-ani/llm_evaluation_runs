module special_number_counter(
  input clk,          // clock
  input rst_n,        // active-low reset
  input start,        // start computation
  input [15:0] n_bin, // input number (binary)
  input [3:0] k,      // operation count target (0-5)
  output reg [31:0] count, // result
  output reg done     // computation complete
);

  // Internal state
  localparam IDLE = 2'b00;
  localparam COUNTING = 2'b01;
  localparam DONE = 2'b10;

  reg [1:0] state, state_next;
  reg [31:0] count_next;
  reg [15:0] x, x_next;          // current number being evaluated
  reg [4:0] cycles, cycles_next; // cycles elapsed since start (0..20)
  reg done_next;

  // Combinational bit-counting tree (5-bit result, sufficient for [0:16])
  function [4:0] popcount (input [15:0] data);
    integer i;
    begin
      popcount = 0;
      for (i = 0; i < 16; i = i + 1)
        popcount = popcount + data[i];
    end
  endfunction

  // Sequential minimum-operation calculator to exactly k reductions
  // returns number of iterative popcounts needed to reach 1, or 0 for x==0
  function [3:0] min_ops_seq (input [15:0] x);
    reg [15:0] v;
    reg [3:0] ops;
    reg [4:0] pc;
    begin
      v = x;
      ops = 0;
      if (v == 0) begin
        min_ops_seq = 0;
        return;
      end
      while (v > 1) begin
        pc = popcount(v);
        v = pc;
        ops = ops + 1;
      end
      min_ops_seq = ops;
    end
  endfunction

  // Next-state logic (sequential)
  always @(*) begin
    // default assignments
    state_next = state;
    x_next     = x;
    cycles_next = cycles;
    count_next = count;
    done_next  = done;

    case (state)
      IDLE: begin
        cycles_next = 0;
        if (start) begin
          state_next = COUNTING;
          x_next = 0;
          count_next = 0;
          done_next = 1'b0;
        end else begin
          done_next = 1'b0;
        end
      end

      COUNTING: begin
        // evaluate current x
        if (min_ops_seq(x) == k) begin
          count_next = count + 1;
        end else begin
          count_next = count;
        end

        // advance to next number and cycle count
        if (x < n_bin) begin
          x_next = x + 1;
          cycles_next = cycles + 1;
          state_next = COUNTING;
          done_next = 1'b0;
        end else begin
          // last number processed; final cycle
          cycles_next = cycles + 1;
          state_next = DONE;
          done_next = 1'b1;
        end
      end

      DONE: begin
        // latch result and raise done; stay until start deasserted
        done_next = 1'b1;
        if (!start) begin
          state_next = IDLE;
          done_next = 1'b0;
        end else begin
          state_next = DONE;
        end
        cycles_next = cycles;
        x_next = x;
        count_next = count;
      end

      default: begin
        state_next = IDLE;
      end
    endcase
  end

  // State and output registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state  <= IDLE;
      count  <= 32'b0;
      done   <= 1'b0;
      x      <= 16'b0;
      cycles <= 5'b0;
    end else begin
      state  <= state_next;
      count  <= count_next;
      done   <= done_next;
      x      <= x_next;
      cycles <= cycles_next;
    end
  end

  // Result is valid at cycle 20 (latency requirement)
  // done signals validity; actual result appears at the end of the COUNTING state.

endmodule