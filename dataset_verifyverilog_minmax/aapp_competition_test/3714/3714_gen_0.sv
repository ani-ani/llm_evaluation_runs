module crush_joongoon (
  input clk,
  input rst_n,
  input start,
  input [2:0] crunch_arr [0:7],
  output reg [15:0] t,
  output reg done
);

  // State machine states
  typedef enum logic [1:0] { IDLE = 2'd0, RUN = 2'd1, FINISH = 2'd2 } state_t;
  state_t state;

  // Internal control and traversal state
  logic running, start_rising;
  logic [6:0] step_cnt;          // 0..99 cycle step counter (max 100)
  integer i;                     // Temp for for-loops

  // Single-source traversal state per root (reset each root)
  logic [15:0] path [0:63];      // recorded path (16-bit indices, up to 64 steps)
  logic [7:0] ptop;             // stack pointer (0..8)
  logic [7:0] step_at [0:255];  // step index when node first entered (256足够)
  logic [7:0] root;             // current root being explored
  logic [7:0] start_node;       // start node for current traversal
  logic start_in_cycle;         // found a cycle that includes the start
  logic invalid_cycle;          // cycle not returning to start, or early abort
  logic found_cycle;            // cycle detected for current root

  // LCM accumulator and result
  logic [15:0] lcm_val;
  logic [7:0] cycle_len;
  logic [7:0] adj_len;

  // Edge detect for start pulse
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) start_rising <= 1'b0;
    else        start_rising <= start && !done && !running;
  end

  // GCD and LCM helper functions (unsigned, 16-bit)
  function [15:0] gcd16(input [15:0] a, input [15:0] b);
    [15:0] aa, bb;
    aa = a; bb = b;
    while (bb != 16'd0) begin
      [15:0] t;
      t = bb;
      bb = aa % bb;
      aa = t;
    end
    return aa;
  endfunction

  function [15:0] lcm16(input [15:0] a, input [15:0] b);
    if (a == 16'd0 || b == 16'd0) return 16'd0;
    return (a / gcd16(a, b)) * b;
  endfunction

  // Main state machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= IDLE;
      running <= 1'b0;
      done    <= 1'b0;
      t       <= 16'd0;
      lcm_val <= 16'd1;
      step_cnt <= 7'd0;
      invalid_cycle <= 1'b0;
      // Per-root state reset
      ptop        <= 8'd0;
      start_node  <= 8'd0;
      root        <= 8'd0;
      start_in_cycle <= 1'b0;
      found_cycle <= 1'b0;
      cycle_len   <= 8'd0;
      adj_len     <= 8'd0;
    end else begin
      // Default control signals
      found_cycle <= 1'b0;
      start_in_cycle <= 1'b0;
      invalid_cycle <= invalid_cycle; // hold until state change
      case (state)
        IDLE: begin
          if (start_rising) begin
            // Initialize computation
            state   <= RUN;
            running <= 1'b1;
            done    <= 1'b0;
            t       <= 16'd0;
            lcm_val <= 16'd1;
            step_cnt <= 7'd0;
            invalid_cycle <= 1'b0;
            root        <= 8'd0;
            // Initialize first root traversal
            start_node  <= root;
            ptop        <= 8'd0;
            for (i = 0; i < 256; i++) step_at[i] <= 8'dX;
          end else begin
            running <= 1'b0;
            done    <= done & start; // keep done asserted if start held
          end
        end

        RUN: begin
          if (invalid_cycle) begin
            // Early abort due to invalid detection
            t     <= 16'hFFFF; // -1
            done  <= 1'b1;
            state <= FINISH;
          end else if (step_cnt >= 7'd100) begin
            // Timeout after 100 cycles -> invalid
            t     <= 16'hFFFF;
            done  <= 1'b1;
            state <= FINISH;
          end else begin
            step_cnt <= step_cnt + 1;

            if (ptop == 8'd0) begin
              // Start a new root traversal if none in progress
              start_node  <= root;
              ptop        <= 8'd1;
              path[0]     <= root;
              step_at[root] <= 8'd0;
            end else if (!found_cycle) begin
              // Traverse one edge each cycle
              [15:0] cur_idx;
              [7:0]  next_idx;
              cur_idx  = path[ptop - 1];
              next_idx = crunch_arr[cur_idx[2:0]];

              if (step_at[next_idx] != 8'dX) begin
                // Cycle detected: from step_at[next_idx] to ptop-1
                cycle_len <= ptop - step_at[next_idx];
                found_cycle <= 1'b1;
                // Check whether start is inside this cycle
                if ((step_at[next_idx] <= 0) && (0 < ptop)) start_in_cycle <= 1'b1;
              end else begin
                // Continue traversal
                if (ptop >= 8'd64) begin
                  // Should not happen in functional graph, but guard
                  invalid_cycle <= 1'b1;
                end else begin
                  path[ptop] <= next_idx;
                  step_at[next_idx] <= ptop;
                  ptop <= ptop + 1;
                end
              end
            end else begin
              // Finalize this root: compute adjusted length and update LCM
              if (start_in_cycle) begin
                adj_len <= (cycle_len[0] ? cycle_len : (cycle_len >> 1)); // odd -> L, even -> L/2
                lcm_val <= lcm16(lcm_val, {8'd0, (cycle_len[0] ? cycle_len : (cycle_len >> 1))});
              end else begin
                // Cycle detected does not return to start -> invalid overall
                invalid_cycle <= 1'b1;
              end

              // Prepare next root or finish
              if (root == 8'd7 || invalid_cycle) begin
                t     <= invalid_cycle ? 16'hFFFF : lcm_val;
                done  <= 1'b1;
                state <= FINISH;
              end else begin
                // Move to next root and reset per-root state
                root <= root + 1;
                ptop <= 8'd0;
                for (i = 0; i < 256; i++) step_at[i] <= 8'dX;
              end
            end
          end
        end

        FINISH: begin
          // Hold results until next start pulse
          if (start_rising) begin
            state   <= RUN;
            running <= 1'b1;
            done    <= 1'b0;
            t       <= 16'd0;
            lcm_val <= 16'd1;
            step_cnt <= 7'd0;
            invalid_cycle <= 1'b0;
            root        <= 8'd0;
            start_node  <= 8'd0;
            ptop        <= 8'd0;
            found_cycle <= 1'b0;
            start_in_cycle <= 1'b0;
            cycle_len   <= 8'd0;
            adj_len     <= 8'd0;
            for (i = 0; i < 256; i++) step_at[i] <= 8'dX;
          end else begin
            running <= 1'b0;
            done    <= 1'b1;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
