module student_helper (
  input clk, // clock signal
  input rst_n, // active-low reset
  input cmd, // 0=D command, 1=P command
  input [2:0] student_id, // 0-7 index for D/P command (student 1 = index 0)
  input [15:0] A_in, // A value (D command)
  input [15:0] B_in, // B value (D command)
  output reg [2:0] result_id, // 0=NE, 1-8=student number
  output reg result_valid // high when P result valid
);

  // Internal registers
  logic [15:0] A_reg [0:7];
  logic [15:0] B_reg [0:7];
  logic [7:0] valid_reg;

  // Sequential logic for D command and reset
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_reg <= '0;
    end else begin
      if (cmd == 0) begin  // D command
        A_reg[student_id] <= A_in;
        B_reg[student_id] <= B_in;
        valid_reg[student_id] <= 1'b1;
      end
    end
  end

  // Combinational logic for P command
  always_comb begin
    result_id = 3'b0;
    result_valid = 1'b0;
    
    if (cmd && rst_n) begin  // Process P command when not in reset
      result_valid = 1'b1;
      
      if (valid_reg[student_id]) begin
        logic [15:0] curr_A = A_reg[student_id];
        logic [15:0] curr_B = B_reg[student_id];
        logic found = 1'b0;
        logic [2:0] best_id;
        logic [15:0] best_B_diff;
        logic [15:0] best_A_diff;

        // Search all valid candidates
        for (int i = 0; i < 8; i++) begin
          if (i != student_id && valid_reg[i] && 
              A_reg[i] >= curr_A && B_reg[i] >= curr_B) begin
            logic [15:0] diff_B = B_reg[i] - curr_B;
            logic [15:0] diff_A = A_reg[i] - curr_A;
            
            if (!found || (diff_B < best_B_diff) || 
                (diff_B == best_B_diff && diff_A < best_A_diff)) begin
              found = 1'b1;
              best_id = i;
              best_B_diff = diff_B;
              best_A_diff = diff_A;
            end
          end
        end
        
        result_id = (found) ? (best_id + 1) : 3'b0;
      end
    end
  end

endmodule