module event_deduction (
  input reg clk,
  input reg rst_n,
  input reg start,
  input reg [2:0] D,
  input reg [3:0] M,
  input reg [2:0] imp_A [15:0],
  input reg [2:0] imp_B [15:0],
  input reg [1:0] N,
  input reg [2:0] init_evts [3:0],
  output reg [7:0] result,
  output reg done
);

  // State enumeration
  typedef enum logic [2:0] {
    S_IDLE       = 3'b000,
    S_LOAD       = 3'b001,
    S_FORWARD    = 3'b010,
    S_NECESSITY  = 3'b011,
    S_CHECK      = 3'b100,
    S_DONE       = 3'b101
  } state_t;

  state_t state, next_state;

  // Internal registers
  logic [7:0] mask, next_mask;
  logic [4:0] iter;   // up to 32 iterations

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= S_IDLE;
      mask    <= 8'b0;
      result  <= 8'b0;
      done    <= 1'b0;
      iter    <= 5'b0;
    end else begin
      state   <= next_state;
      mask    <= next_mask;
      result  <= (state == S_DONE) ? next_mask : result;
      done    <= (state == S_DONE);
      iter    <= (state == S_CHECK) ? (iter + 1) : iter;
    end
  end

  // Combinational next-state logic
  always_comb begin
    next_state = state;
    next_mask  = mask;

    case (state)
      S_IDLE: begin
        if (start) begin
          next_state = S_LOAD;
          next_mask  = 8'b0;
        end
      end

      S_LOAD: begin
        // Initialize mask with initial events
        next_mask = 8'b0;
        for (int i = 0; i < 4; i++) begin
          if (i < N) begin
            logic [2:0] evt;
            evt = init_evts[i];
            if (evt >= 1 && evt <= 8) begin
              next_mask[evt - 1] = 1'b1;
            end
          end
        end
        next_state = S_FORWARD;
      end

      S_FORWARD: begin
        // Forward propagation: if source event occurred, set target event
        next_mask = mask;
        for (int i = 0; i < 16; i++) begin
          if (i < M) begin
            logic [2:0] src, dst;
            src = imp_A[i];
            dst = imp_B[i];
            if (src >= 1 && src <= 8 && dst >= 1 && dst <= 8) begin
              if (mask[src - 1] && !next_mask[dst - 1]) begin
                next_mask[dst - 1] = 1'b1;
              end
            end
          end
        end
        next_state = S_NECESSITY;
      end

      S_NECESSITY: begin
        // Necessity propagation: if a target has exactly one source, add that source
        next_mask = mask;
        for (int ev = 0; ev < 8; ev++) begin
          if (mask[ev]) begin
            int cnt;
            logic [2:0] src_unique;
            cnt = 0;
            src_unique = 3'b0;
            for (int i = 0; i < 16; i++) begin
              if (i < M) begin
                logic [2:0] dst;
                dst = imp_B[i];
                if (dst == (ev + 1)) begin
                  cnt++;
                  src_unique = imp_A[i];
                end
              end
            end
            if (cnt == 1) begin
              logic [2:0] src;
              src = src_unique;
              if (src >= 1 && src <= 8 && !mask[src - 1]) begin
                next_mask[src - 1] = 1'b1;
              end
            end
          end
        end
        next_state = S_CHECK;
      end

      S_CHECK: begin
        // Determine if a change occurred and whether to continue
        if (iter >= 5'd31) begin
          // At iteration limit (31) -> final decision
          if (next_mask != mask) begin
            // Allow one final iteration (iteration 32)
            next_state = S_FORWARD;
          end else begin
            next_state = S_DONE;
          end
        end else begin
          // More iterations allowed
          if (next_mask != mask) begin
            next_state = S_FORWARD;
          end else begin
            next_state = S_DONE;
          end
        end
      end

      S_DONE: begin
        // Hold final result and done flag
        next_state = S_DONE;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

endmodule
