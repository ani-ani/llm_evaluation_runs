module max_subarray_sum_repeat(
  input clk,
  input rst_n,
  input start,
  input [1:0] n,
  input [1:0] k,
  input [7:0] a0,
  input [7:0] a1,
  input [7:0] a2,
  input [7:0] a3,
  output reg [15:0] max_sum,
  output reg done
);

  typedef enum logic [1:0] {IDLE=2'b00, INIT=2'b01, PROCESS=2'b10, FINAL=2'b11} state_t;
  state_t state, next_state;

  reg [15:0] max_ending_here, max_so_far;
  reg [15:0] sample_a0, sample_a1, sample_a2, sample_a3;
  reg [1:0] sample_n, sample_k;
  reg [2:0] cycles_left; // elements remaining in current repetition
  reg [2:0] rep_left;    // repetitions remaining (after current)
  reg [2:0] cycles_left_p1; // cycles_left + 1 (used to enter FINAL after last element)
  reg [2:0] elements_processed; // number of elements processed in current repetition
  reg sampled;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      max_sum <= 0;
      done <= 1'b0;
      max_ending_here <= 0;
      max_so_far <= 0;
      sample_a0 <= 0;
      sample_a1 <= 0;
      sample_a2 <= 0;
      sample_a3 <= 0;
      sample_n <= 0;
      sample_k <= 0;
      cycles_left <= 0;
      rep_left <= 0;
      cycles_left_p1 <= 0;
      elements_processed <= 0;
      sampled <= 1'b0;
    end else begin
      state <= next_state;

      if (state == IDLE) begin
        done <= 1'b0;
        if (start) begin
          sample_n <= n;
          sample_k <= k;
          sample_a0 <= a0;
          sample_a1 <= a1;
          sample_a2 <= a2;
          sample_a3 <= a3;
          cycles_left <= n;
          rep_left <= (k > 0) ? (k - 1) : 0;
          elements_processed <= 0;
          cycles_left_p1 <= n + 1;
          sampled <= 1'b1;
          max_ending_here <= 0;
          max_so_far <= 0;
        end
      end else if (state == INIT) begin
        cycles_left <= sample_n;
        rep_left <= (sample_k > 0) ? (sample_k - 1) : 0;
        elements_processed <= 0;
        cycles_left_p1 <= sample_n + 1;
        max_ending_here <= 0;
        max_so_far <= 0;
      end else if (state == PROCESS) begin
        if (sampled) begin
          cycles_left <= cycles_left - 1;
          elements_processed <= elements_processed + 1;
          cycles_left_p1 <= cycles_left;
        end
      end else if (state == FINAL) begin
        max_sum <= max_so_far;
        done <= 1'b1;
      end
    end
  end

  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start && !done) next_state = INIT;
      end
      INIT: begin
        next_state = PROCESS;
      end
      PROCESS: begin
        if (cycles_left_p1 == 1) next_state = FINAL;
      end
      FINAL: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  always @(posedge clk) begin
    if (state == PROCESS) begin
      if (sampled) begin
        logic [7:0] current;
        case (elements_processed[1:0])
          2'b00: current = sample_a0;
          2'b01: current = sample_a1;
          2'b10: current = sample_a2;
          2'b11: current = sample_a3;
        endcase

        max_ending_here = (max_ending_here + $signed(current) > $signed(current)) ?
                          (max_ending_here + $signed(current)) : $signed(current);
        max_so_far = (max_so_far > max_ending_here) ? max_so_far : max_ending_here;

        if (cycles_left == 0) begin
          if (rep_left > 0) begin
            rep_left <= rep_left - 1;
            cycles_left <= sample_n;
            elements_processed <= 0;
            cycles_left_p1 <= sample_n + 1;
          end else begin
            cycles_left <= 0;
            elements_processed <= 0;
            cycles_left_p1 <= 0;
          end
        end
      end
    end
  end

endmodule