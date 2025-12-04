module min_effort_balancing(
  input clk,                   // clock signal
  input rst_n,                 // active-low reset
  input start,                 // pulse high to start computation
  input [2:0] k_in,            // max Bruce operations (0-8)
  input [7:0] seq_bits,        // packed 8-bit sequence (0='(', 1=')')
  input [7:0][10:0] costs,     // 8 cost values (11-bit signed each)
  output reg [10:0] min_effort, // resulting minimal effort (11-bit signed)
  output reg impossible_flag,   // high when result is '?'
  output reg done              // high when computation complete
);

  // Internal state machine
  reg [4:0] state; // 0-15 states for 15-cycle computation
  reg [3:0] balance; // Track balance during sequence scan
  reg [2:0] count; // Count of barrier candidates found
  reg [2:0] i; // Index for sequence processing
  reg [10:0] cand_costs[7:0]; // Candidate barrier costs
  reg [2:0] j; // Loop index for summing
  reg [14:0] sum15; // Temporary sum for min_effort calculation

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= 5'b0;
      min_effort <= 0;
      impossible_flag <= 0;
      done <= 0;
      balance <= 0;
      count <= 0;
      i <= 0;
      for (j = 0; j < 8; j = j + 1) cand_costs[j] <= 11'h7FF;
    end else begin
      case (state)
        5'b0: if (start) state <= 5'b1; else state <= 5'b0;
        
        5'b1: begin // Reset state
          balance <= 0;
          count <= 0;
          i <= 0;
          for (j = 0; j < 8; j = j + 1) cand_costs[j] <= 11'h7FF;
          state <= 5'b10;
        end
        
        5'b10 to 5'b1001: begin // Process sequence bits (states 2-9)
          if (seq_bits[i] == 1'b0) begin // '(' character
            balance <= balance + 1;
          end else begin // ')' character
            if (balance > 0) begin
              balance <= balance - 1;
            end else begin
              if (count < 8) begin
                cand_costs[count] <= costs[i];
                count <= count + 1;
              end
              balance <= 1; // Flip this ')' to '('
            end
          end
          i <= i + 1;
          state <= state + 1;
        end
        
        5'b1010: begin // Sorting state 0: compare 0-1, 2-3, 4-5, 6-7
          reg [10:0] c0, c1, c2, c3, c4, c5, c6, c7;
          c0 = cand_costs[0]; c1 = cand_costs[1];
          c2 = cand_costs[2]; c3 = cand_costs[3];
          c4 = cand_costs[4]; c5 = cand_costs[5];
          c6 = cand_costs[6]; c7 = cand_costs[7];
          
          // Compare 0-1
          if (c0 > c1) begin
            cand_costs[0] <= c1;
            cand_costs[1] <= c0;
          end else begin
            cand_costs[0] <= c0;
            cand_costs[1] <= c1;
          end
          
          // Compare 2-3
          if (c2 > c3) begin
            cand_costs[2] <= c3;
            cand_costs[3] <= c2;
          end else begin
            cand_costs[2] <= c2;
            cand_costs[3] <= c3;
          end
          
          // Compare 4-5
          if (c4 > c5) begin
            cand_costs[4] <= c5;
            cand_costs[5] <= c4;
          end else begin
            cand_costs[4] <= c4;
            cand_costs[5] <= c5;
          end
          
          // Compare 6-7
          if (c6 > c7) begin
            cand_costs[6] <= c7;
            cand_costs[7] <= c6;
          end else begin
            cand_costs[6] <= c6;
            cand_costs[7] <= c7;
          end
          
          state <= 5'b1011;
        end
        
        5'b1011: begin // Sorting state 1: compare 1-2, 3-4, 5-6
          reg [10:0] c0, c1, c2, c3, c4, c5, c6, c7;
          c0 = cand_costs[0]; c1 = cand_costs[1];
          c2 = cand_costs[2]; c3 = cand_costs[3];
          c4 = cand_costs[4]; c5 = cand_costs[5];
          c6 = cand_costs[6]; c7 = cand_costs[7];
          
          // Compare 1-2
          if (c1 > c2) begin
            cand_costs[1] <= c2;
            cand_costs[2] <= c1;
          end else begin
            cand_costs[1] <= c1;
            cand_costs[2] <= c2;
          end
          
          // Compare 3-4
          if (c3 > c4) begin
            cand_costs[3] <= c4;
            cand_costs[4] <= c3;
          end else begin
            cand_costs[3] <= c3;
            cand_costs[4] <= c4;
          end
          
          // Compare 5-6
          if (c5 > c6) begin
            cand_costs[5] <= c6;
            cand_costs[6] <= c5;
          end else begin
            cand_costs[5] <= c5;
            cand_costs[6] <= c6;
          end
          
          state <= 5'b1100;
        end
        
        5'b1100: begin // Sorting state 2: compare 0-1, 2-3, 4-5, 6-7
          reg [10:0] c0, c1, c2, c3, c4, c5, c6, c7;
          c0 = cand_costs[0]; c1 = cand_costs[1];
          c2 = cand_costs[2]; c3 = cand_costs[3];
          c4 = cand_costs[4]; c5 = cand_costs[5];
          c6 = cand_costs[6]; c7 = cand_costs[7];
          
          // Compare 0-1
          if (c0 > c1) begin
            cand_costs[0] <= c1;
            cand_costs[1] <= c0;
          end else begin
            cand_costs[0] <= c0;
            cand_costs[1] <= c1;
          end
          
          // Compare 2-3
          if (c2 > c3) begin
            cand_costs[2] <= c3;
            cand_costs[3] <= c2;
          end else begin
            cand_costs[2] <= c2;
            cand_costs[3] <= c3;
          end
          
          // Compare 4-5
          if (c4 > c5) begin
            cand_costs[4] <= c5;
            cand_costs[5] <= c4;
          end else begin
            cand_costs[4] <= c4;
            cand_costs[5] <= c5;
          end
          
          // Compare 6-7
          if (c6 > c7) begin
            cand_costs[6] <= c7;
            cand_costs[7] <= c6;
          end else begin
            cand_costs[6] <= c6;
            cand_costs[7] <= c7;
          end
          
          state <= 5'b1101;
        end
        
        5'b1101: begin // Sorting state 3: compare 1-2, 3-4, 5-6
          reg [10:0] c0, c1, c2, c3, c4, c5, c6, c7;
          c0 = cand_costs[0]; c1 = cand_costs[1];
          c2 = cand_costs[2]; c3 = cand_costs[3];
          c4 = cand_costs[4]; c5 = cand_costs[5];
          c6 = cand_costs[6]; c7 = cand_costs[7];
          
          // Compare 1-2
          if (c1 > c2) begin
            cand_costs[1] <= c2;
            cand_costs[2] <= c1;
          end else begin
            cand_costs[1] <= c1;
            cand_costs[2] <= c2;
          end
          
          // Compare 3-4
          if (c3 > c4) begin
            cand_costs[3] <= c4;
            cand_costs[4] <= c3;
          end else begin
            cand_costs[3] <= c3;
            cand_costs[4] <= c4;
          end
          
          // Compare 5-6
          if (c5 > c6) begin
            cand_costs[5] <= c6;
            cand_costs[6] <= c5;
          end else begin
            cand_costs[5] <= c5;
            cand_costs[6] <= c6;
          end
          
          state <= 5'b1110;
        end
        
        5'b1110: begin // Sorting state 4: compare 0-1, 2-3, 4-5, 6-7
          reg [10:0] c0, c1, c2, c3, c4, c5, c6, c7;
          c0 = cand_costs[0]; c1 = cand_costs[1];
          c2 = cand_costs[2]; c3 = cand_costs[3];
          c4 = cand_costs[4]; c5 = cand_costs[5];
          c6 = cand_costs[6]; c7 = cand_costs[7];
          
          // Compare 0-1
          if (c0 > c1) begin
            cand_costs[0] <= c1;
            cand_costs[1] <= c0;
          end else begin
            cand_costs[0] <= c0;
            cand_costs[1] <= c1;
          end
          
          // Compare 2-3
          if (c2 > c3) begin
            cand_costs[2] <= c3;
            cand_costs[3] <= c2;
          end else begin
            cand_costs[2] <= c2;
            cand_costs[3] <= c3;
          end
          
          // Compare 4-5
          if (c4 > c5) begin
            cand_costs[4] <= c5;
            cand_costs[5] <= c4;
          end else begin
            cand_costs[4] <= c4;
            cand_costs[5] <= c5;
          end
          
          // Compare 6-7
          if (c6 > c7) begin
            cand_costs[6] <= c7;
            cand_costs[7] <= c6;
          end else begin
            cand_costs[6] <= c6;
            cand_costs[7] <= c7;
          end
          
          state <= 5'b1111;
        end
        
        5'b1111: begin // Final state: calculate result and reset
          if (count > k_in) begin
            impossible_flag <= 1'b1;
            min_effort <= 0;
          end else begin
            reg [2:0] M;
            M = (k_in - count) + 1;
            if (M > count) M = count;
            
            // Sum the first M elements
            sum15 = 0;
            if (M >= 1) sum15 = sum15 + cand_costs[0];
            if (M >= 2) sum15 = sum15 + cand_costs[1];
            if (M >= 3) sum15 = sum15 + cand_costs[2];
            if (M >= 4) sum15 = sum15 + cand_costs[3];
            if (M >= 5) sum15 = sum15 + cand_costs[4];
            if (M >= 6) sum15 = sum15 + cand_costs[5];
            if (M >= 7) sum15 = sum15 + cand_costs[6];
            if (M >= 8) sum15 = sum15 + cand_costs[7];
            
            min_effort <= sum15[10:0];
            impossible_flag <= 1'b0;
          end
          done <= 1'b1;
          state <= 5'b0;
        end
        
        default: state <= 5'b0;
      endcase
    end
  end
endmodule