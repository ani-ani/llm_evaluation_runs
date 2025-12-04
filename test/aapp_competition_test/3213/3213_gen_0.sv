module bat_spell_optimizer(
  input clk,
  input rst_n,
  input start,
  input [3:0] S,
  input [7:0] steps,
  output reg [7:0] result,
  output reg done
);

  // Internal registers
  reg [3:0] current_power;
  reg [7:0] decisions;
  reg [3:0] step_idx;       // 0..7
  reg [4:0] cycle_count;    // To track 16-cycle latency
  reg active;               // Indicates an ongoing optimization

  // Wires for modulo mask
  wire [3:0] s_eff;         // effective S (treat 0 as 1 for modulo)
  wire [15:0] mask;         // modulo mask (2^S - 1), safe for S=0

  assign s_eff = (S == 4'd0) ? 4'd1 : S;
  assign mask = (16'h0001 << s_eff) - 16'h0001;

  // Sequential control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_power <= 4'd1;
      decisions     <= 8'd0;
      step_idx      <= 4'd0;
      cycle_count   <= 5'd0;
      active        <= 1'b0;
      result        <= 8'd0;
      done          <= 1'b0;
    end else begin
      // Default hold
      done <= 1'b0;

      if (start && !active) begin
        // Initialize optimization
        active        <= 1'b1;
        current_power <= 4'd1;
        decisions     <= 8'd0;
        step_idx      <= 4'd0;
        cycle_count   <= 5'd0;
      end else if (active) begin
        // 16-cycle fixed schedule: 2 cycles per step
        cycle_count <= cycle_count + 5'd1;

        // On every odd cycle (1,3,...,15) we process one step
        if (cycle_count[0] == 1'b1 && step_idx < 4'd8) begin
          // Determine operation for current step (MSB first)
          // step0 = steps[7], step1 = steps[6], ..., step7 = steps[0]
          wire op_mul; // 0: +1, 1: *2
          assign op_mul = steps[7 - step_idx];

          // Compute keep and skip candidates
          // keep: apply op
          // skip: no change
          reg [15:0] keep_ext;
          reg [15:0] skip_ext;
          reg [15:0] keep_val;
          reg [15:0] skip_val;

          skip_ext = current_power;
          skip_val = skip_ext & mask;

          if (op_mul) begin
            // multiply by 2
            keep_ext = (current_power << 1);
          end else begin
            // add 1
            keep_ext = current_power + 16'd1;
          end
          keep_val = keep_ext & mask;

          // Choose best (prefer keep on tie)
          if (keep_val >= skip_val) begin
            current_power <= keep_val[3:0];
            decisions[7 - step_idx] <= 1'b1; // keep
          end else begin
            current_power <= skip_val[3:0];
            decisions[7 - step_idx] <= 1'b0; // skip
          end

          step_idx <= step_idx + 4'd1;
        end

        // After cycle 15 (0-based counting) we are done
        if (cycle_count == 5'd15) begin
          result <= decisions;
          done   <= 1'b1;
          active <= 1'b0;
        end
      end
    end
  end

endmodule