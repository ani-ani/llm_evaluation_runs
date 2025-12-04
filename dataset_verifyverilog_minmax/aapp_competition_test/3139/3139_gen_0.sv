module student_helper(
  input clk, // clock signal
  input rst_n, // active-low reset
  input cmd, // 0=D command, 1=P command
  input [2:0] student_id, // 0-7 index for D/P command (student 1 = index 0)
  input [15:0] A_in, // A value (D command)
  input [15:0] B_in, // B value (D command)
  output reg [2:0] result_id, // 0=NE, 1-8=student number
  output reg result_valid // high when P result valid
);

  // Internal storage for 8 students
  reg [15:0] A_reg [0:7];
  reg [15:0] B_reg [0:7];
  reg        valid_reg [0:7];

  integer i;

  // D command: register write on posedge
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      valid_reg <= '{default: 1'b0};
    end else begin
      if (cmd == 1'b0) begin
        A_reg[student_id] <= A_in;
        B_reg[student_id] <= B_in;
        valid_reg[student_id] <= 1'b1;
      end
    end
  end

  // P command: combinational processing and result output
  always_comb begin
    // Default outputs to avoid latches
    result_id = 3'b0;

    if (cmd == 1'b1) begin
      if (valid_reg[student_id]) begin
        // Query student's values
        logic [15:0] qA, qB;
        qA = A_reg[student_id];
        qB = B_reg[student_id];

        // Selection state
        logic [15:0] best_diffB;
        logic [15:0] best_diffA;
        logic [2:0] best_idx;
        logic found;

        best_diffB = 16'hFFFF;
        best_diffA = 16'hFFFF;
        best_idx   = 3'b0;
        found      = 1'b0;

        for (i = 0; i < 8; i++) begin
          if (valid_reg[i] && (i != student_id)) begin
            if ((A_reg[i] >= qA) && (B_reg[i] >= qB)) begin
              logic [15:0] diffA, diffB;
              diffA = A_reg[i] - qA;  // candidate A - query A
              diffB = B_reg[i] - qB;  // candidate B - query B
              if (!found || (diffB < best_diffB) || ((diffB == best_diffB) && (diffA < best_diffA))) begin
                best_diffB = diffB;
                best_diffA = diffA;
                best_idx   = i[2:0];
                found      = 1'b1;
              end
            end
          end
        end

        if (found) begin
          // Convert index (0..7) to student number (1..8)
          result_id = best_idx + 1'b1;
        end else begin
          result_id = 3'b0; // NE
        end
      end else begin
        // Querying an invalid student -> no result
        result_id = 3'b0;
      end
    end
  end

  // result_valid: 1 cycle high for P command
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      result_valid <= 1'b0;
    end else begin
      result_valid <= cmd == 1'b1;
    end
  end

endmodule