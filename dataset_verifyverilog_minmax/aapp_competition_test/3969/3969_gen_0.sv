module plant_replanner (
  input clk,
  input rst_n,
  input start,
  input [1:0] species_data [0:15],
  output reg [4:0] replant_count,
  output reg done
);

  // State encoding
  typedef enum logic {S_IDLE=1'b0, S_RUN=1'b1} state_t;
  state_t state, state_next;

  // Control registers
  reg [4:0] i, i_next;          // position within species_data (0..15)
  reg [4:0] cnt, cnt_next;      // current LNDS length (0..16)

  // Patience sorting tails array
  reg [1:0] tails [0:15];
  integer k;

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      i     <= 5'd0;
      cnt   <= 5'd0;
      for (k = 0; k < 16; k++) tails[k] <= 2'd0;
      done  <= 1'b0;
      replant_count <= 5'd0;
    end else begin
      state <= state_next;
      i     <= i_next;
      cnt   <= cnt_next;
      if (state_next == S_IDLE) begin
        for (k = 0; k < 16; k++) tails[k] <= 2'd0;
      end
      done <= (state_next == S_IDLE) && (state == S_RUN);
      if (state == S_IDLE) begin
        replant_count <= 5'd0;
      end else if (state_next == S_IDLE) begin
        replant_count <= 5'd16 - cnt_next;
      end
    end
  end

  // Combinational next-state logic
  always_comb begin
    state_next = state;
    i_next     = i;
    cnt_next   = cnt;

    case (state)
      S_IDLE: begin
        if (start) begin
          state_next = S_RUN;
          i_next     = 5'd0;
          cnt_next   = 5'd0;
        end
      end

      S_RUN: begin
        i_next = i + 1;
        cnt_next = update_lnds(species_data[i], tails, cnt);
        if (i == 5'd15) begin
          state_next = S_IDLE;
        end
      end

      default: state_next = S_IDLE;
    endcase
  end

  // Function: update tails/cnt for LNDS using patience sorting with upper_bound
  function [4:0] update_lnds;
    input [1:0] val;
    input [1:0] tarray [0:15];
    input [4:0] curr_len;
    reg [4:0] lo, hi, mid;
    reg [1:0] tmp;
    integer idx;
    begin
      // Default: keep current length
      update_lnds = curr_len;

      lo = 5'd0;
      hi = curr_len; // hi in [0,16]

      // Find first index > val (upper bound)
      while (lo < hi) begin
        mid = (lo + hi) >> 1;
        if (tarray[mid] > val) hi = mid;
        else lo = mid + 1;
      end
      idx = lo;

      // Replace or append
      if (idx < 16) begin
        if (idx < curr_len) begin
          tarray[idx] = val; // replace
        end else begin
          tarray[idx] = val; // append (curr_len == idx)
          update_lnds = curr_len + 1;
        end
      end
    end
  endfunction

endmodule
