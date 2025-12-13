module event_deduction(
  input              clk,
  input              rst_n,
  input              start,
  input       [2:0]  D,
  input       [3:0]  M,
  input       [2:0]  imp_A [15:0],
  input       [2:0]  imp_B [15:0],
  input       [1:0]  N,
  input       [2:0]  init_evts [3:0],
  output reg  [7:0]  result,
  output reg         done
);

  // FSM states
  localparam [2:0]
    S_IDLE    = 3'd0,
    S_INIT    = 3'd1,
    S_FWD_IMP = 3'd2,
    S_FWD_UPD = 3'd3,
    S_BWD_IMP = 3'd4,
    S_BWD_UPD = 3'd5,
    S_CHECK   = 3'd6,
    S_DONE    = 3'd7;

  reg [2:0]  state, next_state;

  // Internal registers
  reg [7:0] cur_events;       // current known events mask
  reg [7:0] next_events;      // accumulated new events candidate
  reg [3:0] imp_idx;          // 0..15 iterator
  reg [5:0] iter_cnt;         // up to 32 cycles
  reg       changed;          // indicates any change made in iteration

  // Helper wires
  wire [7:0] event_mask_all = (D == 0) ? 8'h00 : ((8'h01 << D) - 1'b1);

  // FSM sequential
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      cur_events  <= 8'b0;
      next_events <= 8'b0;
      imp_idx     <= 4'd0;
      iter_cnt    <= 6'd0;
      changed     <= 1'b0;
      result      <= 8'b0;
      done        <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done        <= 1'b0;
          result      <= 8'b0;
          cur_events  <= 8'b0;
          next_events <= 8'b0;
          imp_idx     <= 4'd0;
          iter_cnt    <= 6'd0;
          changed     <= 1'b0;
        end

        S_INIT: begin
          // initialize events from init_evts
          cur_events  <= 8'b0;
          next_events <= 8'b0;
          imp_idx     <= 4'd0;
          iter_cnt    <= 6'd0;
          changed     <= 1'b1; // treat initial set as a change
        end

        S_FWD_IMP: begin
          // iterate through implications for forward propagation
          if (imp_idx < M) begin
            // decode current implication
            // A -> B: if A in cur_events then B occurs
            if (imp_A[imp_idx] != 3'd0 && imp_B[imp_idx] != 3'd0) begin
              if (cur_events[imp_A[imp_idx]-1]) begin
                next_events[imp_B[imp_idx]-1] <= 1'b1;
              end
            end
            imp_idx <= imp_idx + 4'd1;
          end
        end

        S_FWD_UPD: begin
          // apply new forward events
          // ensure masked by D (event IDs 1..D)
          next_events      <= (cur_events | next_events) & event_mask_all;
          changed          <= (((cur_events | next_events) & event_mask_all) != cur_events);
          cur_events       <= (cur_events | next_events) & event_mask_all;
          imp_idx          <= 4'd0;
          // clear for next phase accumulation
          // note: keep next_events until after cur_events assign above
          next_events      <= 8'b0;
        end

        S_BWD_IMP: begin
          // backward necessity: for each A->B
          // if B is known and this rule is the only way to get B
          // (i.e., all implications producing B have their A known), then A is necessary.
          // Given DAG and determinism, we approximate by:
          // if B is set and A not set, and no alternative unexplained producer exists,
          // we add A. For efficiency in this small config, we compute locally.
          if (imp_idx < M) begin
            if (imp_A[imp_idx] != 3'd0 && imp_B[imp_idx] != 3'd0) begin
              // indices
              int a_idx;
              int b_idx;
              a_idx = imp_A[imp_idx]-1;
              b_idx = imp_B[imp_idx]-1;
              if (cur_events[b_idx] && !cur_events[a_idx]) begin
                // check if there exists another implication X->B with X not in cur_events
                // that could explain B (i.e., alternative path)
                bit unique_needed;
                unique_needed = 1'b1;
                int j;
                for (j = 0; j < M; j = j + 1) begin
                  if (imp_B[j] == imp_B[imp_idx] && j != imp_idx) begin
                    if (imp_A[j] != 3'd0) begin
                      if (!cur_events[imp_A[j]-1]) begin
                        // alternative unexplained parent exists; cannot force A
                        unique_needed = 1'b0;
                      end
                    end
                  end
                end
                if (unique_needed) begin
                  next_events[a_idx] <= 1'b1;
                end
              end
            end
            imp_idx <= imp_idx + 4'd1;
          end
        end

        S_BWD_UPD: begin
          // apply new backward (necessary) events
          next_events      <= (cur_events | next_events) & event_mask_all;
          changed          <= ((((cur_events | next_events) & event_mask_all)) != cur_events) | changed;
          cur_events       <= (cur_events | next_events) & event_mask_all;
          imp_idx          <= 4'd0;
          next_events      <= 8'b0;
        end

        S_CHECK: begin
          iter_cnt <= iter_cnt + 6'd1;
          if (!changed || iter_cnt >= 6'd31) begin
            result <= cur_events;
            done   <= 1'b1;
          end
          changed <= 1'b0;
        end

        S_DONE: begin
          // hold result and done until next start or reset
          done   <= 1'b1;
          result <= cur_events;
        end

        default: begin
          // safety
          state <= S_IDLE;
        end
      endcase

      // Load initial events once in S_INIT after state update
      if (state == S_INIT) begin
        integer k;
        reg [7:0] init_mask;
        init_mask = 8'b0;
        for (k = 0; k < 4; k = k + 1) begin
          if (k < N && init_evts[k] != 3'd0 && init_evts[k] <= D) begin
            init_mask[init_evts[k]-1] = 1'b1;
          end
        end
        cur_events  <= init_mask & event_mask_all;
        next_events <= 8'b0;
      end
    end
  end

  // FSM combinational next_state
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start) next_state = S_INIT;
      end

      S_INIT: begin
        next_state = S_FWD_IMP;
      end

      S_FWD_IMP: begin
        if (imp_idx >= M) next_state = S_FWD_UPD;
      end

      S_FWD_UPD: begin
        next_state = S_BWD_IMP;
      end

      S_BWD_IMP: begin
        if (imp_idx >= M) next_state = S_BWD_UPD;
      end

      S_BWD_UPD: begin
        next_state = S_CHECK;
      end

      S_CHECK: begin
        if (!changed || iter_cnt >= 6'd31) begin
          next_state = S_DONE;
        end else begin
          next_state = S_FWD_IMP;
        end
      end

      S_DONE: begin
        if (!start) begin
          // wait for start deassertion to avoid retrigger on same pulse
          next_state = S_DONE;
        end
        if (start) begin
          next_state = S_INIT;
        end
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

endmodule