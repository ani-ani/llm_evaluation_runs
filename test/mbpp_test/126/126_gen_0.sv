module common_divisor_sum(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [7:0]  a,
  input  logic [7:0]  b,
  output logic [7:0]  sum,
  output logic        done
);

  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    INIT  = 2'b01,
    CALC  = 2'b10,
    DONE  = 2'b11
  } state_t;

  state_t       state, next_state;
  logic [7:0]   i_cnt, next_i_cnt;
  logic [7:0]   min_ab, next_min_ab;
  logic [7:0]   sum_reg, next_sum_reg;
  logic         start_d;

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      i_cnt     <= 8'd0;
      min_ab    <= 8'd0;
      sum_reg   <= 8'd0;
      start_d   <= 1'b0;
      done      <= 1'b0;
      sum       <= 8'd0;
    end else begin
      state     <= next_state;
      i_cnt     <= next_i_cnt;
      min_ab    <= next_min_ab;
      sum_reg   <= next_sum_reg;
      start_d   <= start;
      done      <= (next_state == DONE);
      if (next_state == DONE)
        sum <= next_sum_reg;
    end
  end

  // Combinational next-state and datapath logic
  always_comb begin
    next_state   = state;
    next_i_cnt   = i_cnt;
    next_min_ab  = min_ab;
    next_sum_reg = sum_reg;

    case (state)
      IDLE: begin
        next_sum_reg = 8'd0;
        next_i_cnt   = 8'd0;
        next_min_ab  = 8'd0;
        if (start && !start_d) begin
          next_state = INIT;
        end
      end

      INIT: begin
        // Determine min(a,b)
        if (a <= b)
          next_min_ab = a;
        else
          next_min_ab = b;
        next_sum_reg = 8'd0;
        next_i_cnt   = 8'd1;
        next_state   = CALC;
      end

      CALC: begin
        next_state = CALC;
        next_i_cnt = i_cnt;
        next_sum_reg = sum_reg;

        // Perform one iteration for current i_cnt
        if ((a % i_cnt == 8'd0) && (b % i_cnt == 8'd0)) begin
          next_sum_reg = sum_reg + i_cnt;
        end

        if (i_cnt == min_ab) begin
          // Completed all iterations
          next_state = DONE;
        end else begin
          next_i_cnt = i_cnt + 8'd1;
        end
      end

      DONE: begin
        // Hold result until start deasserted and reasserted
        if (!start)
          next_state = IDLE;
      end

      default: begin
        next_state   = IDLE;
        next_i_cnt   = 8'd0;
        next_min_ab  = 8'd0;
        next_sum_reg = 8'd0;
      end
    endcase
  end

endmodule