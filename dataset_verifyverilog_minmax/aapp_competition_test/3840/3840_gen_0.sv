module pirates_game_solver(
  input clk,
  input rst_n,
  input start,
  input [3:0] n_in,
  input [9:0] a[0:14],
  output reg [13:0] result,
  output reg done
);

  // Internal registers
  reg [3:0] x_ptr;          // current chest index (15-1)
  reg [13:0] acc_sum;        // accumulated moves sum
  reg [9:0] data_reg[0:14]; // working copy of chest values
  reg [1:0] state;          // FSM state (0=IDLE, 1=PROC, 2=DONE)

  // Validity flags (combinational)
  wire [3:0] n_eff;
  assign n_eff = (n_in > 4'd15) ? 4'd15 : n_in;
  wire is_invalid;
  assign is_invalid = (n_eff <= 4'd1) | (n_eff[0] == 1'b0); // n<=1 or even
  wire [3:0] start_n;
  assign start_n = (is_invalid) ? 4'd0 : n_eff; // 0 means invalid for this FSM

  // FSM next-state and datapath
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= 2'd0;
      done    <= 1'b0;
      result  <= 14'sd0;
      acc_sum <= 14'sd0;
      x_ptr   <= 4'd0;
      // Initialize working storage
      for (int i = 0; i < 15; i++) data_reg[i] <= 10'd0;
    end else begin
      case (state)
        2'd0: begin // IDLE
          done <= 1'b0;
          if (start) begin
            if (is_invalid) begin
              // 1-cycle validity check => go to DONE with -1
              result  <= 14'($signed(-1));
              acc_sum <= 14'sd0;
              x_ptr   <= 4'd0;
              state   <= 2'd2; // DONE
            end else begin
              // Load data and initialize for 15 cycles processing
              for (int i = 0; i < 15; i++) data_reg[i] <= a[i];
              acc_sum <= 14'sd0;
              // start at index (n-1), but clamp to 14 to be safe
              x_ptr <= (start_n > 4'd14) ? 4'd14 : (start_n - 1);
              state <= 2'd1; // PROCESSING
            end
          end else begin
            result <= 14'sd0;
          end
        end

        2'd1: begin // PROCESSING (fixed 15 cycles)
          // Perform one step per cycle for x = 15 down to 1 (child index in 0..14)
          if (x_ptr >= 4'd1) begin
            // Safe local copies
            reg [3:0] x;
            reg [9:0] left, right, parent;
            x      = x_ptr;
            left   = data_reg[x << 1];
            right  = data_reg[(x << 1) + 1];
            parent = data_reg[x];
            // Accumulate the max of children
            acc_sum <= acc_sum + (left >= right ? left : right);
            // Subtract max from parent (new value stays within 10 bits)
            data_reg[x] <= parent - (left >= right ? left : right);
            // Move to next chest
            x_ptr <= x_ptr - 1;
          end
          // After processing x=1, next cycle will be last (x=0)
          if (x_ptr == 4'd1) begin
            // Prepare to add root in the very next cycle
            // Nothing else to do here; just wait for x_ptr to become 0
          end
          // Last processing cycle: x_ptr == 0, add root a[0]
          if (x_ptr == 4'd0) begin
            result <= acc_sum + data_reg[0];
            // One-cycle DONE pulse follows
            state  <= 2'd2;
            done   <= 1'b1; // optional early assertion; spec says 1 cycle in DONE
          end
        end

        2'd2: begin // DONE (assert done for 1 cycle, then return to IDLE)
          done   <= 1'b0;
          result <= result; // latch result
          state  <= 2'd0;
        end

        default: begin
          state <= 2'd0;
          done  <= 1'b0;
        end
      endcase
    end
  end

endmodule
