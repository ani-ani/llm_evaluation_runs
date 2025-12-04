module loot_divider(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start computation
  input [2:0] k, // Number of denominations (1-8)
  input [7:0] x [7:0], // 8-element array of coin counts (each 8-bit)
  output reg [31:0] left_behind, // Result
  output reg done // High when computation completes
);

  // State encoding
  localparam IDLE = 2'b00;
  localparam PROCESS = 2'b01;
  localparam DONE = 2'b10;

  // State machine registers
  reg [1:0] state, next_state;
  reg [2:0] denom_index; // 0 to 7
  reg [8:0] carry_reg;   // 9 bits to hold carry
  reg [31:0] left_behind_reg; // Internal accumulator

  // Combinational next state logic
  always @(*) begin
    case (state)
      IDLE: next_state = (start) ? PROCESS : IDLE;
      PROCESS: next_state = (denom_index < k) ? PROCESS : DONE;
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      denom_index <= 0;
      carry_reg <= 0;
      left_behind_reg <= 0;
      done <= 0;
      left_behind <= 0;
    end
    else begin
      state <= next_state;

      // Initialize when entering PROCESS from IDLE
      if (state == IDLE && next_state == PROCESS) begin
        left_behind_reg <= 0;
        carry_reg <= 0;
        denom_index <= 0;
      end
      // Process denomination during PROCESS state
      else if (state == PROCESS) begin
        if (denom_index < k) begin
          // Calculate current coins (9-bit: 8-bit + 9-bit carry)
          wire [8:0] current_coins = carry_reg + {1'b0, x[denom_index]};
          wire [8:0] adjusted_coins = current_coins - (current_coins[0] ? 1 : 0);
          
          // Leave one coin if LSB is 1
          if (current_coins[0]) begin
            left_behind_reg <= left_behind_reg + (1 << denom_index);
          end
          
          // Carry to next denomination
          carry_reg <= adjusted_coins >> 1;
          denom_index <= denom_index + 1;
        end
      end
      // Output result in DONE state
      else if (state == DONE) begin
        done <= 1;
        left_behind <= left_behind_reg;
      end
    end
  end
endmodule