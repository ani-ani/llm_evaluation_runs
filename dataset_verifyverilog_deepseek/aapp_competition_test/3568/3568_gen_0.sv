module floppy_organ_scheduler(
  input clk,
  input rst_n,
  input start,
  input [1:0] f,
  input [15:0] t_0,
  input [1:0] n_0,
  input [15:0] intervals_0 [0:7],
  input [15:0] t_1,
  input [1:0] n_1,
  input [15:0] intervals_1 [0:7],
  input [15:0] t_2,
  input [1:0] n_2,
  input [15:0] intervals_2 [0:7],
  output reg possible,
  output reg done
);

  localparam [2:0] IDLE = 3'b000,
                   CHECK_FREQ = 3'b001,
                   CHECK_INTERVAL = 3'b010,
                   VERIFY_PAUSE = 3'b011,
                   DONE = 3'b100;

  reg [2:0] state, next_state;
  reg [1:0] freq_index;
  reg [15:0] timer_count;
  reg [1:0] interval_index;
  reg all_freq_ok;
  reg [15:0] current_t;
  reg [1:0] current_n;
  reg [15:0] current_intervals [0:7];
  reg [15:0] prev_end;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      possible <= 0;
      done <= 0;
      freq_index <= 0;
      timer_count <= 0;
      interval_index <= 0;
      all_freq_ok <= 1;
      prev_end <= 0;
    end else begin
      state <= next_state;

      if (state == IDLE && start) begin
        timer_count <= 10 + 20*f;
        done <= 0;
        possible <= 0;
        all_freq_ok <= 1;
        freq_index <= 0;
      end else if (timer_count > 0) begin
        timer_count <= timer_count - 1;
      end else begin
        done <= 1;
        possible <= (state == DONE && all_freq_ok) ? 1'b1 : 1'b0;
      end

      case (state)
        IDLE:;
        CHECK_FREQ: begin
          case (freq_index)
            0: begin
              current_t <= t_0;
              current_n <= n_0;
              current_intervals <= intervals_0;
            end
            1: begin
              current_t <= t_1;
              current_n <= n_1;
              current_intervals <= intervals_1;
            end
            2: begin
              current_t <= t_2;
              current_n <= n_2;
              current_intervals <= intervals_2;
            end
          endcase
          interval_index <= 0;
          prev_end <= 0;
        end
        CHECK_INTERVAL: begin
          if (interval_index == 0) begin
            if (current_intervals[0] >= current_intervals[1] || current_intervals[1] > current_t)
              all_freq_ok <= 0;
            prev_end <= current_intervals[1];
          end else begin
            if (current_intervals[2*interval_index] >= current_intervals[2*interval_index + 1] ||
                current_intervals[2*interval_index + 1] > current_t ||
                current_intervals[2*interval_index] < prev_end)
              all_freq_ok <= 0;
            prev_end <= current_intervals[2*interval_index + 1];
          end
          if (interval_index < current_n - 1)
            interval_index <= interval_index + 1;
        end
        VERIFY_PAUSE:;
        DONE:;
      endcase
    end
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE: if (start) next_state = CHECK_FREQ;
      CHECK_FREQ: next_state = CHECK_INTERVAL;
      CHECK_INTERVAL: begin
        if (all_freq_ok == 0) next_state = DONE;
        else if (interval_index == current_n - 1) begin
          if (freq_index < f - 1) begin
            next_state = CHECK_FREQ;
          end else next_state = DONE;
          if (freq_index < 2) freq_index = freq_index + 1;
        end else next_state = VERIFY_PAUSE;
      end
      VERIFY_PAUSE: next_state = CHECK_INTERVAL;
      DONE: next_state = DONE;
    endcase
    if (timer_count == 0 && state != IDLE) next_state = DONE;
  end
endmodule