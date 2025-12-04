module toy_assignment(
  input clk,
  input rst_n,
  input start,
  input [3:0] in_kid_id,
  input [3:0] in_toy_id,
  input [15:0] in_event_time,
  input [2:0] in_event_count,
  output reg [7:0] assignments,
  output reg impossible_flag,
  output reg done
);

  localparam K = 4;
  localparam T = 4;
  localparam LOGK = 2;
  localparam MAX_EVENTS = 8;
  localparam S0 = 2'b00;
  localparam S1 = 2'b01;
  localparam S2 = 2'b10;

  reg [1:0] state, state_next;
  reg [3:0] event_idx, event_idx_next;
  reg [3:0] event_idx_d;
  reg [2:0] in_event_count_r;
  reg start_r, start_pulse;
  reg [15:0] play_sum [0:3][0:3];
  reg [3:0] kid_used, toy_used, kid_used_next, toy_used_next;
  reg [3:0] pref_mat [0:3][0:3];
  reg pair_invalid [0:3][0:3];
  reg [7:0] mapping, mapping_next;
  reg found, found_next;
  reg [2:0] i, j;
  reg [3:0] cur_pref;
  reg [3:0] kid_id2b, toy_id2b;
  reg valid_kid, valid_toy;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S0;
      event_idx <= 4'd0;
      event_idx_d <= 4'd0;
      in_event_count_r <= 3'd0;
      start_r <= 1'b0;
      assignments <= 8'd0;
      impossible_flag <= 1'b0;
      done <= 1'b0;
      kid_used <= 4'd0;
      toy_used <= 4'd0;
      mapping <= 8'd0;
      found <= 1'b0;
    end else begin
      state <= state_next;
      event_idx <= event_idx_next;
      event_idx_d <= event_idx;
      in_event_count_r <= in_event_count;
      start_r <= start;
      assignments <= mapping_next;
      impossible_flag <= ~found_next & (state_next == S0) & (start_pulse | (state != S0));
      done <= (state_next == S0);
      kid_used <= kid_used_next;
      toy_used <= toy_used_next;
      mapping <= mapping_next;
      found <= found_next;
    end
  end

  always @* begin
    start_pulse = start & ~start_r;
    state_next = state;
    event_idx_next = event_idx;
    mapping_next = mapping;
    found_next = found;
    kid_used_next = kid_used;
    toy_used_next = toy_used;

    for (i = 0; i < 4; i = i + 1) begin
      for (j = 0; j < 4; j = j + 1) begin
        pref_mat[i][j] = 4'd15;
        pair_invalid[i][j] = 1'b1;
        play_sum[i][j] = 16'd0;
      end
    end

    if (state == S0) begin
      event_idx_next = 4'd0;
      mapping_next = 8'd0;
      found_next = 1'b0;
      kid_used_next = 4'd0;
      toy_used_next = 4'd0;
      if (start_pulse) begin
        state_next = S1;
      end
    end else if (state == S1) begin
      state_next = S2;
      event_idx_next = 4'd0;
      kid_used_next = 4'd0;
      toy_used_next = 4'd0;
    end else if (state == S2) begin
      if (event_idx < in_event_count_r) begin
        event_idx_next = event_idx + 1;
        kid_id2b = in_kid_id[1:0];
        toy_id2b = in_toy_id[1:0];
        valid_kid = (in_kid_id < 4);
        valid_toy = (in_toy_id < 4);
        if (valid_kid && valid_toy) begin
          play_sum[kid_id2b][toy_id2b] = play_sum[kid_id2b][toy_id2b] + in_event_time;
          pref_mat[kid_id2b][toy_id2b] = (pref_mat[kid_id2b][toy_id2b] > in_event_time) ? in_event_time : pref_mat[kid_id2b][toy_id2b];
          pair_invalid[kid_id2b][toy_id2b] = 1'b0;
        end
      end else begin
        state_next = S0;
      end
    end
  end

  always @* begin
    for (i = 0; i < K; i = i + 1) begin
      for (j = 0; j < T; j = j + 1) begin
        if (pair_invalid[i][j]) begin
          pref_mat[i][j] = 4'd15;
        end
      end
    end

    mapping_next = 8'd0;
    found_next = 1'b0;

    for (i = 0; i < K; i = i + 1) begin
      for (j = 0; j < T; j = j + 1) begin
        cur_pref = pref_mat[i][j];
        if (cur_pref == 4'd15) begin
          continue;
        end
        if ((&kid_used) == 1'b0 && (&toy_used) == 1'b0) begin
          mapping_next = {i[1:0], j[1:0]} | (mapping_next & 8'hF0);
          found_next = 1'b1;
          kid_used_next = 4'b0001 << i;
          toy_used_next = 4'b0001 << j;
        end else if (found_next) begin
          mapping_next = mapping_next;
        end else begin
          if ((kid_used[i] == 1'b0) && (toy_used[j] == 1'b0)) begin
            mapping_next = {i[1:0], j[1:0]} | (mapping_next & 8'hF0);
            found_next = 1'b1;
            kid_used_next = 4'b0001 << i;
            toy_used_next = 4'b0001 << j;
          end
        end
      end
    end
  end

endmodule
