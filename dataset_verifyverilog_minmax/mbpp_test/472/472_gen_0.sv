module consecutive_checker (
  input clk,
  input rst_n,
  input start,
  input signed [7:0] array_in [0:7],
  output reg consecutive,
  output reg done
);

  typedef enum logic [1:0] { IDLE = 2'b00, SORT = 2'b01, DONE = 2'b10 } state_t;
  state_t state, state_next;

  // Sorting storage
  logic signed [7:0] arr [0:7];
  logic signed [7:0] arr_next [0:7];

  // Bubble sort indices and cycle counter
  logic [3:0] i_pass, i_pass_next;
  logic [3:0] j_pass, j_pass_next;
  logic [6:0] sort_count, sort_count_next;
  logic last_pass, last_pass_next;

  // Checker signals (calculated during sorting to be ready at end)
  logic [7:0] dups, dups_next;
  logic signed [7:0] min_val, min_val_next;
  logic signed [7:0] max_val, max_val_next;
  logic consecutive_next;

  // Helpers
  function [7:0] popcount8 (input [7:0] v);
    integer k;
    popcount8 = 8'b0;
    for (k = 0; k < 8; k++) popcount8 = popcount8 + v[k];
  endfunction

  // Sequential block (clocked)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= IDLE;
      done           <= 1'b1;
      consecutive    <= 1'b0;
      i_pass         <= 4'd0;
      j_pass         <= 4'd0;
      sort_count     <= 7'd0;
      last_pass      <= 1'b0;
      arr[0]         <= 8'sb0;
      arr[1]         <= 8'sb0;
      arr[2]         <= 8'sb0;
      arr[3]         <= 8'sb0;
      arr[4]         <= 8'sb0;
      arr[5]         <= 8'sb0;
      arr[6]         <= 8'sb0;
      arr[7]         <= 8'sb0;
    end else begin
      state          <= state_next;
      done           <= (state_next == DONE);
      consecutive    <= (state_next == DONE) ? consecutive_next : 1'b0;
      i_pass         <= i_pass_next;
      j_pass         <= j_pass_next;
      sort_count     <= sort_count_next;
      last_pass      <= last_pass_next;
      dups           <= dups_next;
      min_val        <= min_val_next;
      max_val        <= max_val_next;
      arr[0]         <= arr_next[0];
      arr[1]         <= arr_next[1];
      arr[2]         <= arr_next[2];
      arr[3]         <= arr_next[3];
      arr[4]         <= arr_next[4];
      arr[5]         <= arr_next[5];
      arr[6]         <= arr_next[6];
      arr[7]         <= arr_next[7];
    end
  end

  // Combinational next-logic
  always_comb begin
    // Defaults
    state_next      = state;
    arr_next        = arr;
    i_pass_next     = i_pass;
    j_pass_next     = j_pass;
    sort_count_next = sort_count;
    last_pass_next  = last_pass;
    dups_next       = dups;
    min_val_next    = min_val;
    max_val_next    = max_val;
    consecutive_next = 1'b0;

    case (state)
      IDLE: begin
        if (!rst_n) begin
          state_next = IDLE;
        end else if (start) begin
          // Load input array and start bubble sort
          arr_next        = array_in;
          state_next      = SORT;
          sort_count_next = 7'd0;
          i_pass_next     = 4'd0;
          j_pass_next     = 4'd0;
          last_pass_next  = 1'b0;
          dups_next       = 8'b0;
          min_val_next    = array_in[0];
          max_val_next    = array_in[0];
        end
      end

      SORT: begin
        // Bubble sort with 8 elements, 64 cycles worst-case
        sort_count_next = sort_count + 7'd1;
        i_pass_next     = i_pass;
        j_pass_next     = j_pass;
        last_pass_next  = last_pass;
        arr_next        = arr;
        dups_next       = dups;
        min_val_next    = min_val;
        max_val_next    = max_val;

        // Compute one swap per cycle (worst-case 56 swaps + 7 final null passes = 63, but we use 64-cycle budget)
        if (!last_pass) begin
          // Update min/max and duplicates mask during sorting
          dups_next[7:0] = dups[7:0];
          min_val_next   = min_val;
          max_val_next   = max_val;
          for (int k = 0; k < 8; k++) begin
            // min/max
            if (arr[k] < min_val_next) min_val_next = arr[k];
            if (arr[k] > max_val_next) max_val_next = arr[k];
            // duplicates mask
            for (int p = 0; p < k; p++) begin
              if (arr[k] == arr[p]) dups_next[k] = 1'b1;
            end
          end
          // Bubble step
          j_pass_next = j_pass;
          i_pass_next = i_pass;
          if (j_pass < (4'd7 - i_pass)) begin
            if (arr[j_pass] > arr[j_pass + 1]) begin
              arr_next[j_pass]     = arr[j_pass + 1];
              arr_next[j_pass + 1] = arr[j_pass];
            end else begin
              arr_next[j_pass]     = arr[j_pass];
              arr_next[j_pass + 1] = arr[j_pass + 1];
            end
            j_pass_next = j_pass + 4'd1;
          end else begin
            j_pass_next = 4'd0;
            if (i_pass < 4'd7) begin
              i_pass_next = i_pass + 4'd1;
            end else begin
              last_pass_next = 1'b1;
            end
          end
        end

        // After 64 cycles, finish
        if (sort_count_next == 7'd64) begin
          // Verify: max - min + 1 == 8
          logic signed [8:0] span;
          span = max_val_next - min_val_next + 9'sd1;
          consecutive_next = (span == 9'sd8) && (popcount8(dups_next) == 8'd0);
          state_next = DONE;
        end
      end

      DONE: begin
        // Wait for start deassert or stay until next start
        if (!start) state_next = IDLE;
        else state_next = DONE;
      end

      default: state_next = IDLE;
    endcase
  end

endmodule
