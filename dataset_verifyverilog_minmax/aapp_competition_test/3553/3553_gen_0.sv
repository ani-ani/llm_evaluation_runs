module shortest_subarray_finder #(
  parameter N = 8,
  parameter K = 4
)(
  input clk,
  input rst_n,
  input start,
  input [2:0] query_type, // 0=update, 1=query
  input [2:0] position,   // 0-7
  input [1:0] value,      // 1-4
  output reg [3:0] result, // subarray length (0-8, 15=-1)
  output reg done
);
  // Internal array and related state
  reg [1:0] arr [0:N-1];
  reg [1:0] arr_next [0:N-1];
  reg [K-1:0] target_mask;
  reg [K-1:0] presence;
  reg [3:0] min_len;
  reg [3:0] sub_len;
  reg window_active;
  reg [2:0] l, r;
  reg [2:0] l_next, r_next;
  reg [3:0] min_len_next, sub_len_next;
  reg window_active_next;
  reg [K-1:0] presence_next;
  reg q_started, q_started_next;
  reg query_active, query_active_next;
  reg [1:0] shift_en, shift_en_next;
  reg [3:0] result_q1, result_q2;
  reg [3:0] result_q1_next, result_q2_next;
  reg [2:0] i;

  function [K-1:0] presence_of;
    input [1:0] v;
    input [K-1:0] mask;
    begin
      presence_of = mask;
      if (v >= 1 && v <= K) begin
        presence_of[v-1] = 1'b1;
      end
    end
  endfunction

  function [K-1:0] update_presence;
    input [K-1:0] cur_presence;
    input [1:0] old_v;
    input [1:0] new_v;
    input [K-1:0] mask;
    reg [1:0] v;
    begin
      update_presence = cur_presence;
      // Clear old value contribution if it is within 1..K
      if (old_v >= 1 && old_v <= K) begin
        v = old_v;
        // Check if old value is still present in the whole array after removal
        // We will recompute presence by scanning the entire array
        update_presence = {K{1'b0}};
        for (i = 0; i < N; i = i + 1) begin
          if (arr_next[i] >= 1 && arr_next[i] <= K) begin
            update_presence[arr_next[i]-1] = 1'b1;
          end
        end
      end
      // Add new value contribution (also recompute to be safe)
      if (new_v >= 1 && new_v <= K) begin
        // recompute for new_v also
        update_presence = {K{1'b0}};
        for (i = 0; i < N; i = i + 1) begin
          if (arr_next[i] >= 1 && arr_next[i] <= K) begin
            update_presence[arr_next[i]-1] = 1'b1;
          end
        end
      end
    end
  endfunction

  always @(*) begin
    // Default: keep state
    arr_next = arr;
    target_mask = {K{1'b1}};
    q_started_next = q_started;
    query_active_next = query_active;
    window_active_next = window_active;
    l_next = l;
    r_next = r;
    min_len_next = min_len;
    sub_len_next = sub_len;
    presence_next = presence;
    shift_en_next = shift_en;
    result_q1_next = result_q1;
    result_q2_next = result_q2;

    if (start) begin
      q_started_next = 1'b1;
      shift_en_next = 2'b11; // load q1,q2 in next two cycles
    end else begin
      // Shift pipeline for DONE/result timing (keep it moving)
      if (shift_en[0]) begin
        result_q1_next = min_len; // computed after 8 cycles of sliding window
        result_q1 = result_q1_next; // not used directly later
      end
      if (shift_en[1]) begin
        result_q2_next = result_q1; // one more cycle delay
        result_q2 = result_q2_next;
      end
      shift_en_next = {1'b0, shift_en[0]};
    end

    if (start) begin
      if (query_type == 3'b0) begin
        // Update path: one-cycle update
        arr_next[position] = value;
        // recompute presence after update for correctness
        presence_next = {K{1'b0}};
        for (i = 0; i < N; i = i + 1) begin
          if (arr_next[i] >= 1 && arr_next[i] <= K) begin
            presence_next[arr_next[i]-1] = 1'b1;
          end
        end
        min_len_next = 0; // not used for update
        sub_len_next = 0; // not used
        window_active_next = 1'b0;
        l_next = 0;
        r_next = 0;
        query_active_next = 1'b0; // update consumes the start
      end else begin
        // Query path: start sliding window, 8 cycles worst-case
        arr_next = arr; // array not changing during query
        query_active_next = 1'b1;
        window_active_next = 1'b1;
        l_next = 0;
        r_next = 0;
        min_len_next = 4'b0; // will be updated during window search
        sub_len_next = 4'b0;
        presence_next = {K{1'b0}};
        // Initialize presence based on arr at start (same as current arr)
        for (i = 0; i < N; i = i + 1) begin
          if (arr[i] >= 1 && arr[i] <= K) begin
            presence_next[arr[i]-1] = 1'b1;
          end
        end
      end
    end else if (query_active) begin
      // Sliding window for query
      arr_next = arr; // keep array stable
      presence_next = presence;
      min_len_next = min_len;
      sub_len_next = sub_len;
      l_next = l;
      r_next = r;
      window_active_next = window_active;

      if (window_active) begin
        // Expand right edge
        r_next = r + 1;
        // Update presence with arr[r]
        if (r < N) begin
          presence_next = presence_of(arr[r], target_mask);
          sub_len_next = r_next - l_next; // length after including r
          // Check if window now covers all K values
          if (presence_next == target_mask) begin
            // Try shrink from left while condition holds
            while (l_next < r_next) begin
              if ((presence_of(arr[l_next], target_mask) == target_mask) &&
                  ((r_next - (l_next + 1)) >= min_len_next || min_len_next == 4'b0)) begin
                l_next = l_next + 1;
                // If after moving l we still have all values, continue shrinking
                presence_next = {K{1'b0}};
                for (i = l_next; i < r_next; i = i + 1) begin
                  if (arr[i] >= 1 && arr[i] <= K) begin
                    presence_next[arr[i]-1] = 1'b1;
                  end
                end
              end else begin
                break;
              end
            end
            // Update min_len to current good window
            if ((r_next - l_next) < min_len_next || min_len_next == 4'b0) begin
              min_len_next = r_next - l_next;
            end
            // Once we found a window, deactivate to finish in 8 cycles
            window_active_next = 1'b0;
          end else begin
            // Not yet complete; min_len stays as is
          end
        end else begin
          // r reached N; finish windowing
          window_active_next = 1'b0;
        end
      end else begin
        // Window finished; hold values
        query_active_next = 1'b0;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset: initialize array to all 1s, reset control/state
      for (i = 0; i < N; i = i + 1) begin
        arr[i] <= 2'b01;
      end
      arr_next <= arr;
      target_mask <= {K{1'b1}};
      presence <= {K{1'b0}};
      min_len <= 4'b0;
      sub_len <= 4'b0;
      window_active <= 1'b0;
      l <= 3'b0;
      r <= 3'b0;
      q_started <= 1'b0;
      query_active <= 1'b0;
      shift_en <= 2'b00;
      result_q1 <= 4'b0;
      result_q2 <= 4'b0;
      result <= 4'b0;
      done <= 1'b0;
    end else begin
      // Update registers with next values
      arr <= arr_next;
      target_mask <= {K{1'b1}};
      presence <= presence_next;
      min_len <= min_len_next;
      sub_len <= sub_len_next;
      window_active <= window_active_next;
      l <= l_next;
      r <= r_next;
      q_started <= q_started_next;
      query_active <= query_active_next;
      shift_en <= shift_en_next;
      result_q1 <= result_q1_next;
      result_q2 <= result_q2_next;

      // Update result based on pipeline: q_started 0->1, then q1, then q2
      if (q_started) begin
        // After 10 cycles: place result
        if (shift_en[1]) begin
          result <= result_q2; // result_q2 contains min_len from 8-cycle computation
        end else begin
          result <= result; // hold
        end
      end else begin
        result <= 4'b0; // not started or after done
      end

      // DONE pulses for one cycle 10 cycles after start
      if (q_started && shift_en[1]) begin
        done <= 1'b1;
      end else begin
        done <= 1'b0;
      end
    end
  end
endmodule
