module vote_optimizer (
  input clk,
  input rst_n,
  input start,
  input [3:0] v,
  input [15:0] p_i [0:6],
  input [15:0] b_i [0:6],
  output reg [15:0] b_v,
  output reg done
);

  localparam K = 16; // number of Yraglac positions (ballot width)
  localparam IDLE = 3'b000;
  localparam INIT = 3'b001;
  localparam EVAL_TOTAL = 3'b010;
  localparam EVAL_WEIGHT = 3'b011;
  localparam EVAL_NEXT_COMB = 3'b100;
  localparam COMPARE_AND_NEXT_BV = 3'b101;
  localparam DONE = 3'b110;

  // Accumulators for expected value (Q8.8 fixed-point)
  reg [31:0] sum_q88;
  reg [31:0] best_q88;
  reg [15:0] best_bv_r;

  // b_v counter and combination enumeration
  reg [15:0] b_v_counter;
  reg [7:0] comb_count;         // up to 2^(v-1), v<=8 -> fits in 8 bits
  reg [7:0] num_combs;
  reg [15:0] cur_total;         // current total ballots (b_v + selected b_i)
  reg [7:0] ywin_cnt;           // number of Yraglac wins (0..K)

  // pipeline for per-combination aggregation (Q8.8)
  reg [31:0] acc_q88;

  // snapshot of inputs captured at start
  reg [15:0] p_snapshot [0:6];
  reg [15:0] b_snapshot [0:6];

  // FSM state
  reg [2:0] state, next_state;

  // help: popcount for 16 bits
  function [4:0] popcount16;
    input [15:0] x;
    begin
      casez (x)
        16'bzzzzzzzzzzzzzzzz: popcount16 = 5'd0;
        16'b??????????????z1: popcount16 = popcount16({x[15:1], 1'b0}) + 1;
        16'b??????????????z0: popcount16 = popcount16({x[15:1], 1'b0});
      endcase
    end
  endfunction

  // FSM sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
    end else begin
      state <= next_state;
      if (state == DONE) done <= 1'b1;
      else if (state != DONE) done <= 1'b0;
    end
  end

  // Main combinational logic
  always @(*) begin
    // defaults
    next_state = state;

    case (state)
      IDLE: begin
        if (start) begin
          // latch snapshot of inputs
          p_snapshot[0] = p_i[0]; p_snapshot[1] = p_i[1]; p_snapshot[2] = p_i[2];
          p_snapshot[3] = p_i[3]; p_snapshot[4] = p_i[4]; p_snapshot[5] = p_i[5];
          p_snapshot[6] = p_i[6];
          b_snapshot[0] = b_i[0]; b_snapshot[1] = b_i[1]; b_snapshot[2] = b_i[2];
          b_snapshot[3] = b_i[3]; b_snapshot[4] = b_i[4]; b_snapshot[5] = b_i[5];
          b_snapshot[6] = b_i[6];
          next_state = INIT;
        end else begin
          next_state = IDLE;
        end
      end

      INIT: begin
        b_v_counter = 16'd0;
        num_combs = (v >= 2) ? (1 << (v - 1)) : 8'd1; // 2^(v-1), at least 1 to avoid div-by-zero
        best_q88 = 32'd0;
        best_bv_r = 16'd0;
        next_state = EVAL_TOTAL;
      end

      EVAL_TOTAL: begin
        cur_total = b_v_counter + b_snapshot[0]; // voter 0 always participates
        ywin_cnt = 5'd0; // popcount result (0..16) fits in 5 bits
        acc_q88 = 32'd0;
        comb_count = 8'd0;
        next_state = EVAL_WEIGHT;
      end

      EVAL_WEIGHT: begin
        // count wins for current b_v candidate under current combination
        ywin_cnt = popcount16(cur_total);
        // accumulate probability-weighted wins in Q8.8
        acc_q88 = acc_q88 + ({16'd0, ywin_cnt} * p_snapshot[comb_count[2:0]]);
        next_state = EVAL_NEXT_COMB;
      end

      EVAL_NEXT_COMB: begin
        if (comb_count + 1 < num_combs) begin
          comb_count = comb_count + 1;
          // voter i participates if (comb_count & (1<<(i-1))) != 0 (i from 1..v-1)
          // accumulate selected ballots into cur_total
          if (v > 1) begin
            if (comb_count[0]) cur_total = cur_total + b_snapshot[1];
            if (v > 2 && comb_count[1]) cur_total = cur_total + b_snapshot[2];
            if (v > 3 && comb_count[2]) cur_total = cur_total + b_snapshot[3];
            if (v > 4 && comb_count[3]) cur_total = cur_total + b_snapshot[4];
            if (v > 5 && comb_count[4]) cur_total = cur_total + b_snapshot[5];
            if (v > 6 && comb_count[5]) cur_total = cur_total + b_snapshot[6];
          end
          next_state = EVAL_WEIGHT;
        end else begin
          next_state = COMPARE_AND_NEXT_BV;
        end
      end

      COMPARE_AND_NEXT_BV: begin
        sum_q88 = acc_q88; // final expected value for this b_v (Q8.8)
        if ((b_v_counter == 16'd0) || (sum_q88 > best_q88)) begin
          best_q88 = sum_q88;
          best_bv_r = b_v_counter;
        end
        if (b_v_counter + 1 <= 16'd65535) begin
          b_v_counter = b_v_counter + 1;
          next_state = EVAL_TOTAL;
        end else begin
          next_state = DONE;
        end
      end

      DONE: begin
        b_v = best_bv_r;
        if (!start) next_state = IDLE; // deassert done on deassertion of start
        else next_state = DONE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Output ballot
  always @(posedge clk) begin
    if (state == DONE) b_v <= best_bv_r;
  end

endmodule
