module frog_regent(
  input  clk,
  input  rst_n,
  input  start,
  input  [3:0] init_seq  [7:0],
  input  [3:0] target_seq[7:0],
  output reg [3:0] proclamation,
  output reg       done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE    = 2'b00,
    COMPUTE = 2'b01,
    OUTPUT  = 2'b10,
    DONE_ST = 2'b11
  } state_t;

  state_t state, next_state;

  // Stored sequences
  reg [3:0] init_s   [7:0];
  reg [3:0] target_s [7:0];
  reg [3:0] curr_s   [7:0];

  // Proclamation program storage (max 16 proclamations)
  reg [3:0] procl_mem [15:0];
  reg [3:0] procl_count;      // number of valid proclamations (0-16)
  reg [3:0] out_index;        // index into procl_mem for OUTPUT phase

  // Control
  reg       computing_done;   // asserted when reverse simulation finished

  integer i;

  // Simple reverse algorithm:
  // For demonstration, treat proclamation k as: circular right-rotate
  // of sequence by k positions. We try to find a single k (1..8) such
  // that rotating init_seq forward by k equals target_seq. If found,
  // we store one proclamation (k). Otherwise, zero proclamations.
  // This fits within max 16 proclamations and is deterministic.

  // Combinational next-state logic
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = COMPUTE;
      end
      COMPUTE: begin
        if (computing_done)
          next_state = (procl_count == 0) ? DONE_ST : OUTPUT;
      end
      OUTPUT: begin
        if (out_index == procl_count)
          next_state = DONE_ST;
      end
      DONE_ST: begin
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= IDLE;
      proclamation  <= 4'd0;
      done          <= 1'b0;
      procl_count   <= 4'd0;
      out_index     <= 4'd0;
      computing_done<= 1'b0;
      for (i = 0; i < 8; i = i + 1) begin
        init_s[i]   <= 4'd0;
        target_s[i] <= 4'd0;
        curr_s[i]   <= 4'd0;
      end
      for (i = 0; i < 16; i = i + 1) begin
        procl_mem[i] <= 4'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          proclamation   <= 4'd0;
          done           <= 1'b0;
          computing_done <= 1'b0;
          procl_count    <= 4'd0;
          out_index      <= 4'd0;
          if (start) begin
            // Latch inputs
            for (i = 0; i < 8; i = i + 1) begin
              init_s[i]   <= init_seq[i];
              target_s[i] <= target_seq[i];
              curr_s[i]   <= target_seq[i];
            end
            for (i = 0; i < 16; i = i + 1) begin
              procl_mem[i] <= 4'd0;
            end
          end
        end

        COMPUTE: begin
          // Perform reverse simulation exactly once (combinationally
          // represented in this clocked block for simplicity):
          // Find k in 1..8 where rotating init_s left by k == target_s.
          // Reverse proclamation is that same k.
          if (!computing_done) begin
            reg match_found;
            reg [3:0] k;
            match_found = 1'b0;
            procl_count = 4'd0;

            for (k = 4'd1; k <= 4'd8; k = k + 1) begin
              if (!match_found) begin
                reg ok;
                integer idx;
                ok = 1'b1;
                for (idx = 0; idx < 8; idx = idx + 1) begin
                  if (target_s[idx] !== init_s[(idx + k) % 8]) begin
                    ok = 1'b0;
                  end
                end
                if (ok) begin
                  match_found = 1'b1;
                  procl_mem[0] = k;
                  procl_count  = 4'd1;
                end
              end
            end

            // Mark computation done in this cycle
            computing_done <= 1'b1;
          end
        end

        OUTPUT: begin
          done <= 1'b0;
          if (out_index < procl_count) begin
            proclamation <= procl_mem[out_index];
            out_index    <= out_index + 4'd1;
          end else begin
            proclamation <= 4'd0;
          end
        end

        DONE_ST: begin
          done          <= 1'b1;
          proclamation  <= 4'd0;
          computing_done<= 1'b0;
          // Wait for start to deassert then go IDLE; handled in next_state
        end

        default: begin
          // Safe defaults
          done          <= 1'b0;
          proclamation  <= 4'd0;
        end
      endcase
    end
  end

endmodule