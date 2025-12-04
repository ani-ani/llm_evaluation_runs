module balanced_concatenation(
  input clk,
  input rst_n,
  input start,
  input [7:0] str1_bits,
  input [7:0] str2_bits,
  output reg result,
  output reg done
);

  // State machine states
  localparam IDLE = 2'b00;
  localparam CHECK_ORDER1 = 2'b01;
  localparam CHECK_ORDER2 = 2'b10;
  localparam DONE = 2'b11;

  // State and next state
  reg [1:0] state, next_state;
  
  // Counters for balance checking
  reg [3:0] cnt1, next_cnt1;
  reg [3:0] cnt2, next_cnt2;
  
  // Balance counters (signed to handle negative values)
  reg signed [4:0] bal1, next_bal1;
  reg signed [4:0] bal2, next_bal2;
  
  // Validity flags
  reg valid1, next_valid1;
  reg valid2, next_valid2;
  
  // Result and done registers (internal)
  reg result_reg, next_result_reg;
  reg done_reg, next_done_reg;

  // Concatenated bit vectors for both orders
  wire [15:0] concat1 = {str1_bits, str2_bits};  // str1+str2
  wire [15:0] concat2 = {str2_bits, str1_bits};  // str2+str1

  // Current bit extraction for concatenation
  wire [15:0] current_bit1 = concat1[15 - cnt1];
  wire [15:0] current_bit2 = concat2[15 - cnt2];

  // Next state and output logic
  always @(*) begin
    // Default assignments
    next_state = state;
    next_cnt1 = cnt1;
    next_cnt2 = cnt2;
    next_bal1 = bal1;
    next_bal2 = bal2;
    next_valid1 = valid1;
    next_valid2 = valid2;
    next_result_reg = result_reg;
    next_done_reg = 1'b0;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = CHECK_ORDER1;
          next_cnt1 = 4'b0;
          next_bal1 = 5'b0;
          next_valid1 = 1'b1;
        end
      end

      CHECK_ORDER1: begin
        if (valid1) begin
          if (cnt1 < 4'b1111) begin
            // Process next character
            if (current_bit1[0] == 1'b0) begin  // '(' character
              next_bal1 = bal1 + 1;
            end else begin  // ')' character
              next_bal1 = bal1 - 1;
            end
            
            // Check for negative balance
            if (next_bal1 < 0) begin
              next_valid1 = 1'b0;
            end
            
            next_cnt1 = cnt1 + 1;
          end else begin
            // Check completed - all 16 characters processed
            if (valid1 && (bal1 == 0)) begin
              next_state = DONE;
              next_result_reg = 1'b1;
            end else begin
              next_state = CHECK_ORDER2;
              next_cnt2 = 4'b0;
              next_bal2 = 5'b0;
              next_valid2 = 1'b1;
            end
          end
        end else begin
          // Early termination - order1 is invalid
          next_state = CHECK_ORDER2;
          next_cnt2 = 4'b0;
          next_bal2 = 5'b0;
          next_valid2 = 1'b1;
        end
      end

      CHECK_ORDER2: begin
        if (valid2) begin
          if (cnt2 < 4'b1111) begin
            // Process next character
            if (current_bit2[0] == 1'b0) begin  // '(' character
              next_bal2 = bal2 + 1;
            end else begin  // ')' character
              next_bal2 = bal2 - 1;
            end
            
            // Check for negative balance
            if (next_bal2 < 0) begin
              next_valid2 = 1'b0;
            end
            
            next_cnt2 = cnt2 + 1;
          end else begin
            // Check completed - all 16 characters processed
            if (valid2 && (bal2 == 0)) begin
              next_state = DONE;
              next_result_reg = 1'b1;
            end else begin
              next_state = DONE;
              next_result_reg = 1'b0;
            end
          end
        end else begin
          // Early termination - order2 is invalid
          next_state = DONE;
          next_result_reg = 1'b0;
        end
      end

      DONE: begin
        next_done_reg = 1'b1;
        next_state = IDLE;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cnt1 <= 4'b0;
      cnt2 <= 4'b0;
      bal1 <= 5'b0;
      bal2 <= 5'b0;
      valid1 <= 1'b1;
      valid2 <= 1'b1;
      result_reg <= 1'b0;
      done_reg <= 1'b0;
    end else begin
      state <= next_state;
      cnt1 <= next_cnt1;
      cnt2 <= next_cnt2;
      bal1 <= next_bal1;
      bal2 <= next_bal2;
      valid1 <= next_valid1;
      valid2 <= next_valid2;
      result_reg <= next_result_reg;
      done_reg <= next_done_reg;
    end
  end

  // Output assignments
  assign result = result_reg;
  assign done = done_reg;

endmodule