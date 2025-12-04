module max_card_score (
  input clk,                // Clock
  input rst_n,            // Active-low reset
  input start,            // Start computation (pulse high to begin)
  input [7:0] a,          // Number of 'o' cards (0-255)
  input [7:0] b,          // Number of 'x' cards (0-255)
  output reg signed [16:0] max_score,  // Maximum score (signed 17-bit)
  output reg done          // High when computation completes
);

  // State machine states
  localparam IDLE = 2'b00;
  localparam SPECIAL = 2'b01;
  localparam LOOP = 2'b10;
  localparam DONE = 2'b11;
  
  // State register
  reg [1:0] state;
  
  // Loop counter for 16 iterations
  reg [4:0] cycle_count;
  
  // Precomputed values
  reg [8:0] min_value;  // min(a+2, b+1)
  reg [16:0] max_so_far;  // Current maximum during loop
  
  // Division table for quotient and remainder
  reg [15:0] div_table[0:4095]; // 4096 entries (b*16 + i-2)
  
  // Compute v1 and v2 for current iteration
  reg [7:0] i;
  reg [7:0] quo;
  reg [7:0] rem;
  reg [15:0] v1;
  reg [15:0] v2;
  reg [16:0] score;
  integer div_index;
  
  // Initialize division table with iterative subtraction
  integer b_idx, i_idx;
  initial begin
    for (b_idx = 0; b_idx < 256; b_idx = b_idx + 1) begin
      for (i_idx = 2; i_idx <= 17; i_idx = i_idx + 1) begin
        // Iterative subtraction to compute quotient and remainder
        rem = b_idx;
        quo = 0;
        while (rem >= i_idx) begin
          rem = rem - i_idx;
          quo = quo + 1;
        end
        div_table[b_idx*16 + (i_idx-2)] = {quo, rem};
      end
    end
  end
  
  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      max_score <= 0;
      cycle_count <= 0;
      min_value <= 0;
      max_so_far <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SPECIAL;
            done <= 0;
          end
        end
        
        SPECIAL: begin
          if (a == 0) begin
            // Special case: a=0
            max_score <= -b * b;
            done <= 1;
            state <= DONE;
          end else if (b == 0) begin
            // Special case: b=0
            max_score <= a * a;
            done <= 1;
            state <= DONE;
          end else begin
            // Normal case: start loop
            min_value <= (a+2 < b+1) ? (a+2) : (b+1);
            max_so_far <= 17'h10000; // Initialize to minimum signed value
            cycle_count <= 0;
            state <= LOOP;
          end
        end
        
        LOOP: begin
          // Current i value
          i = 2 + cycle_count;
          
          if (i <= min_value) begin
            // Get division results from table
            div_index = b*16 + (i-2);
            {quo, rem} = div_table[div_index];
            
            // Compute v1 = (a+2-i)^2 + (i-2)
            v1 = (a+2-i) * (a+2-i) + (i-2);
            
            // Compute v2 = rem*(quo+1)^2 + (i-rem)*quo^2
            v2 = rem * (quo+1) * (quo+1) + (i-rem) * quo * quo;
            
            // Compute score difference (signed)
            score = $signed(v1) - $signed(v2);
            
            // Update maximum
            if (score > max_so_far) begin
              max_so_far <= score;
            end
          end
          
          // Increment cycle counter
          cycle_count <= cycle_count + 1;
          
          // Check if loop is complete (16 cycles)
          if (cycle_count == 15) begin
            max_score <= max_so_far;
            done <= 1;
            state <= DONE;
          end
        end
        
        DONE: begin
          if (start) begin
            state <= IDLE;
          end
        end
      endcase
    end
  end
  
endmodule