module max_non_square(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // start signal
  input signed [15:0] arr [0:7], // 8x16-bit signed array
  output reg signed [15:0] result, // max non-square found
  output reg done // high when result valid
);

  // State definitions
  localparam IDLE = 2'b00;
  localparam COMPARE = 2'b01;
  localparam DONE = 2'b10;

  // State and index registers
  reg [1:0] state, next_state;
  reg [2:0] index;
  reg [15:0] curr_max;
  reg [15:0] current_element; // Register to hold current array element

  // Next state logic
  always @(*) begin
    case (state)
      IDLE: next_state = start ? COMPARE : IDLE;
      COMPARE: next_state = (index == 3'd7) ? DONE : COMPARE;
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // State update and control logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 16'h8000; // Minimum value
      done <= 1'b0;
      index <= 3'd0;
      curr_max <= 16'h8000;
      current_element <= 16'h0;
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (next_state == COMPARE) begin
            index <= 3'd0;
            curr_max <= 16'h8000; // Reset to minimum
          end
        end
        COMPARE: begin
          // Capture current element for next cycle
          current_element <= arr[index];
          // Update index for next cycle
          index <= index + 1;
          // Update current max if current element is non-square and larger
          if (is_non_square && (current_element > curr_max)) begin
            curr_max <= current_element;
          end
        end
        DONE: begin
          result <= curr_max;
          done <= 1'b1;
        end
      endcase
    end
  end

  // Combinational logic for non-square detection
  wire is_non_square;
  
  // Unrolled square root calculation (8 stages)
  // Stage 0: Check 128
  wire [7:0] cand0 = 8'd128;
  wire [15:0] prod0 = cand0 * cand0;
  wire [7:0] y0 = (prod0 <= current_element) ? cand0 : 8'd0;
  
  // Stage 1: Check 64
  wire [7:0] cand1 = y0 + 8'd64;
  wire [15:0] prod1 = cand1 * cand1;
  wire [7:0] y1 = (prod1 <= current_element) ? cand1 : y0;
  
  // Stage 2: Check 32
  wire [7:0] cand2 = y1 + 8'd32;
  wire [15:0] prod2 = cand2 * cand2;
  wire [7:0] y2 = (prod2 <= current_element) ? cand2 : y1;
  
  // Stage 3: Check 16
  wire [7:0] cand3 = y2 + 8'd16;
  wire [15:0] prod3 = cand3 * cand3;
  wire [7:0] y3 = (prod3 <= current_element) ? cand3 : y2;
  
  // Stage 4: Check 8
  wire [7:0] cand4 = y3 + 8'd8;
  wire [15:0] prod4 = cand4 * cand4;
  wire [7:0] y4 = (prod4 <= current_element) ? cand4 : y3;
  
  // Stage 5: Check 4
  wire [7:0] cand5 = y4 + 8'd4;
  wire [15:0] prod5 = cand5 * cand5;
  wire [7:0] y5 = (prod5 <= current_element) ? cand5 : y4;
  
  // Stage 6: Check 2
  wire [7:0] cand6 = y5 + 8'd2;
  wire [15:0] prod6 = cand6 * cand6;
  wire [7:0] y6 = (prod6 <= current_element) ? cand6 : y5;
  
  // Stage 7: Check 1
  wire [7:0] cand7 = y6 + 8'd1;
  wire [15:0] prod7 = cand7 * cand7;
  wire [7:0] y7 = (prod7 <= current_element) ? cand7 : y6;
  
  // Final square root value
  wire [7:0] sqrt_val = y7;
  wire [15:0] sqrt_sq = sqrt_val * sqrt_val;
  
  // Determine if non-square
  assign is_non_square = (current_element < 0) || (sqrt_sq != current_element);

endmodule
