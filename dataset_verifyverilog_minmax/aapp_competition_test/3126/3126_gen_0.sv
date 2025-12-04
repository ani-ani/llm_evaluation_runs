module frog_jump_calculator(
  input clk, // Clock signal
  input rst_n, // Active-low reset
  input [1:0] cmd_type, // 00: add frog, 01: remove frog, 10: change target
  input [15:0] cmd_data, // Position data for command
  input cmd_valid, // Pulse high for 1 cycle when command valid
  output reg [4:0] total_jumps, // Result: minimal total jumps
  output reg result_valid // High when output valid
);

  // Register file
  reg [15:0] frog_positions [0:7]; // Up to 8 frog positions (16-bit each)
  reg [3:0] frog_count;            // Number of frogs (0..8)
  reg [15:0] current_target;       // Current target position

  // Pipeline stage 2 capture (s1_*): values used for k calculation
  reg [15:0] s1_target;
  reg [15:0] s1_positions [0:7];
  reg [3:0] s1_frog_count;

  // Stage 1 command pipeline latches
  reg [1:0] s1_cmd_type;
  reg [15:0] s1_cmd_data;
  reg s1_cmd_valid;

  // Stage 2 pipeline controls
  reg s2_cmd_valid;
  wire s2_result_valid;
  reg [4:0] s2_total_jumps;

  // wires for k computation (combinational, stage 2)
  wire [4:0] frog_k [0:7];
  wire [4:0] max_k_wire;

  // Compute k for each frog in parallel
  function [4:0] compute_k;
    input [15:0] pos;
    input [15:0] target;
    reg [15:0] d;
    reg [5:0] k; // 0..31, need one extra bit for loop bound
    reg [16:0] T; // triangular number (k*(k+1))/2, fits in 17 bits for k<=31
  begin
    d = (pos >= target) ? (pos - target) : (target - pos);
    compute_k = 5'd0;
    // Search smallest k where T_k >= d and parity(T_k) == parity(d)
    for (k = 6'd0; k <= 6'd31; k = k + 1) begin
      T = k * (k + 1) / 2;
      if (T >= d) begin
        // parity match: both even or both odd
        if ((T[0] == d[0])) begin
          compute_k = k[4:0];
          break;
        end
      end
    end
    // Fallback (should never trigger for k<=31 given d<=65535 and T_31=496):
    if (compute_k == 5'd0 && (T < d || T[0] != d[0])) begin
      compute_k = 5'd31;
    end
  end
  endfunction

  // Stage 2: per-frog k calculations (combinational)
  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : k_per_frog
      assign frog_k[i] = (i < s1_frog_count) ? compute_k(s1_positions[i], s1_target) : 5'd0;
    end
  endgenerate

  // Stage 2: find max k across frogs (combinational)
  assign max_k_wire = (frog_k[0] >= frog_k[1] && frog_k[0] >= frog_k[2] && frog_k[0] >= frog_k[3] &&
                       frog_k[0] >= frog_k[4] && frog_k[0] >= frog_k[5] && frog_k[0] >= frog_k[6] && frog_k[0] >= frog_k[7]) ? frog_k[0] :
                      (frog_k[1] >= frog_k[2] && frog_k[1] >= frog_k[3] && frog_k[1] >= frog_k[4] &&
                       frog_k[1] >= frog_k[5] && frog_k[1] >= frog_k[6] && frog_k[1] >= frog_k[7]) ? frog_k[1] :
                      (frog_k[2] >= frog_k[3] && frog_k[2] >= frog_k[4] && frog_k[2] >= frog_k[5] &&
                       frog_k[2] >= frog_k[6] && frog_k[2] >= frog_k[7]) ? frog_k[2] :
                      (frog_k[3] >= frog_k[4] && frog_k[3] >= frog_k[5] &&
                       frog_k[3] >= frog_k[6] && frog_k[3] >= frog_k[7]) ? frog_k[3] :
                      (frog_k[4] >= frog_k[5] && frog_k[4] >= frog_k[6] && frog_k[4] >= frog_k[7]) ? frog_k[4] :
                      (frog_k[5] >= frog_k[6] && frog_k[5] >= frog_k[7]) ? frog_k[5] :
                      (frog_k[6] >= frog_k[7]) ? frog_k[6] : frog_k[7];

  // Pipeline control signals
  assign s2_result_valid = s2_cmd_valid;

  // Sequential logic: reset, pipeline registers, and register file updates
  integer idx;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset register file and pipeline
      for (idx = 0; idx < 8; idx = idx + 1) begin
        frog_positions[idx] <= 16'd0;
        s1_positions[idx] <= 16'd0;
      end
      frog_count <= 4'd0;
      current_target <= 16'd0;
      s1_cmd_type <= 2'b00;
      s1_cmd_data <= 16'd0;
      s1_cmd_valid <= 1'b0;
      s1_target <= 16'd0;
      s1_frog_count <= 4'd0;
      s2_cmd_valid <= 1'b0;
      s2_total_jumps <= 5'd0;
      result_valid <= 1'b0;
      total_jumps <= 5'd0;
    end else begin
      // Pipeline stage 1: register command, update register file, and capture stage-2 snapshot
      s1_cmd_type <= cmd_type;
      s1_cmd_data <= cmd_data;
      s1_cmd_valid <= cmd_valid;

      // Stage 2 snapshot (values used for the next k calculation)
      s1_target <= current_target;
      s1_frog_count <= frog_count;
      for (idx = 0; idx < 8; idx = idx + 1) begin
        s1_positions[idx] <= frog_positions[idx];
      end

      // Process command in stage 1 (when cmd_valid is high for 1 cycle)
      if (cmd_valid) begin
        case (cmd_type)
          2'b00: begin // Add frog
            if (frog_count < 4'd8) begin
              frog_positions[frog_count] <= cmd_data;
              frog_count <= frog_count + 1;
            end
            // If full, ignore add
          end
          2'b01: begin // Remove first matching position
            if (frog_count > 4'd0) begin
              // Find first matching frog
              if (frog_positions[0] == cmd_data) begin
                // Remove at 0 -> shift left by 1
                for (idx = 0; idx < 7; idx = idx + 1) begin
                  frog_positions[idx] <= frog_positions[idx + 1];
                end
                frog_positions[7] <= 16'd0;
                frog_count <= frog_count - 1;
              end else if (frog_positions[1] == cmd_data) begin
                for (idx = 1; idx < 7; idx = idx + 1) begin
                  frog_positions[idx] <= frog_positions[idx + 1];
                end
                frog_positions[7] <= 16'd0;
                frog_count <= frog_count - 1;
              end else if (frog_positions[2] == cmd_data) begin
                for (idx = 2; idx < 7; idx = idx + 1) begin
                  frog_positions[idx] <= frog_positions[idx + 1];
                end
                frog_positions[7] <= 16'd0;
                frog_count <= frog_count - 1;
              end else if (frog_positions[3] == cmd_data) begin
                for (idx = 3; idx < 7; idx = idx + 1) begin
                  frog_positions[idx] <= frog_positions[idx + 1];
                end
                frog_positions[7] <= 16'd0;
                frog_count <= frog_count - 1;
              end else if (frog_positions[4] == cmd_data) begin
                for (idx = 4; idx < 7; idx = idx + 1) begin
                  frog_positions[idx] <= frog_positions[idx + 1];
                end
                frog_positions[7] <= 16'd0;
                frog_count <= frog_count - 1;
              end else if (frog_positions[5] == cmd_data) begin
                for (idx = 5; idx < 7; idx = idx + 1) begin
                  frog_positions[idx] <= frog_positions[idx + 1];
                end
                frog_positions[7] <= 16'd0;
                frog_count <= frog_count - 1;
              end else if (frog_positions[6] == cmd_data) begin
                frog_positions[6] <= frog_positions[7];
                frog_positions[7] <= 16'd0;
                frog_count <= frog_count - 1;
              end else if (frog_positions[7] == cmd_data) begin
                frog_positions[7] <= 16'd0;
                frog_count <= frog_count - 1;
              end
              // If not found, no change
            end
          end
          2'b10: begin // Change target
            current_target <= cmd_data;
          end
          default: begin
            // No-op for undefined cmd_type
          end
        endcase
      end

      // Pipeline stage 2: one cycle after stage 1
      s2_cmd_valid <= s1_cmd_valid;
      if (s1_cmd_valid) begin
        s2_total_jumps <= max_k_wire;
      end

      // Outputs: result appears 2 cycles after cmd_valid
      result_valid <= s2_result_valid;
      total_jumps <= s2_total_jumps;
    end
  end

endmodule