module student_helper(
  input clk,
  input rst_n,
  input cmd, // 0=D, 1=P
  input [2:0] student_id,
  input [15:0] A_in,
  input [15:0] B_in,
  output reg [2:0] result_id, // 0=NE, 1-8=student
  output reg result_valid
);

  // Internal storage
  reg [15:0] A_reg [7:0];
  reg [15:0] B_reg [7:0];
  reg        valid_reg [7:0];

  // Wires for P command combinational logic
  reg [2:0]  best_idx;
  reg [15:0] best_deltaB;
  reg [15:0] best_deltaA;
  reg        best_found;

  integer i;

  // Sequential block: handle reset, D command storage, and registered outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Clear valid_reg and outputs
      for (i = 0; i < 8; i = i + 1) begin
        valid_reg[i] <= 1'b0;
        A_reg[i]     <= 16'd0;
        B_reg[i]     <= 16'd0;
      end
      result_id    <= 3'd0;
      result_valid <= 1'b0;
    end else begin
      // Default: drop result_valid unless new P result
      result_valid <= 1'b0;

      // D command: store incoming data
      if (cmd == 1'b0) begin
        A_reg[student_id]   <= A_in;
        B_reg[student_id]   <= B_in;
        valid_reg[student_id] <= 1'b1;
      end

      // Register P command result (combinational decision)
      if (cmd == 1'b1) begin
        if (best_found) begin
          // best_idx is 0-7; output needs 1-8
          result_id    <= best_idx + 3'd1;
        end else begin
          result_id    <= 3'd0; // NE
        end
        result_valid <= 1'b1;
      end
    end
  end

  // Combinational block for P command candidate search
  always @* begin
    // Default values
    best_found  = 1'b0;
    best_idx    = 3'd0;
    best_deltaB = 16'hFFFF;
    best_deltaA = 16'hFFFF;

    // Only search when cmd==1 and query student is valid
    if (cmd == 1'b1 && valid_reg[student_id]) begin
      // Reference values
      for (i = 0; i < 8; i = i + 1) begin
        if (i != student_id && valid_reg[i]) begin
          // Check dominance: A_i >= A_q AND B_i >= B_q
          if (A_reg[i] >= A_reg[student_id] && B_reg[i] >= B_reg[student_id]) begin
            // Compute differences
            // Safe since condition ensures non-negative differences
            reg [15:0] deltaB;
            reg [15:0] deltaA;
            deltaB = B_reg[i] - B_reg[student_id];
            deltaA = A_reg[i] - A_reg[student_id];

            if (!best_found) begin
              best_found  = 1'b1;
              best_idx    = i[2:0];
              best_deltaB = deltaB;
              best_deltaA = deltaA;
            end else begin
              // Compare with current best: smaller deltaB wins, tie -> smaller deltaA
              if (deltaB < best_deltaB ||
                  (deltaB == best_deltaB && deltaA < best_deltaA)) begin
                best_idx    = i[2:0];
                best_deltaB = deltaB;
                best_deltaA = deltaA;
              end
            end
          end
        end
      end
    end
  end

endmodule