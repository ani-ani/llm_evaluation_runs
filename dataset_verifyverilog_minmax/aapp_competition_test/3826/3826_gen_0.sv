module min_subsegment_removal(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [31:0] a[0:7],
  output reg [3:0] min_size,
  output reg done
);
  
  // State definitions
  localparam IDLE = 2'b00;
  localparam CHECK_UNIQUE = 2'b01;
  localparam CALCULATE = 2'b10;
  localparam DONE = 2'b11;
  
  // State machine registers
  reg [1:0] state, next_state;
  reg [2:0] l_count, r_count;
  reg first_cycle_calc;
  
  // Uniqueness check registers and signals
  reg [7:0] include;
  reg duplicate_found_reg, duplicate_found_comb;
  reg check_all;
  
  // Generate the include mask combinatorially
  always @(*) begin
    include = 8'b0;
    if (check_all) begin
      // Include all valid elements
      include[0] = (n > 0);
      include[1] = (n > 1);
      include[2] = (n > 2);
      include[3] = (n > 3);
      include[4] = (n > 4);
      include[5] = (n > 5);
      include[6] = (n > 6);
      include[7] = (n > 7);
    end else begin
      // Include elements not in removal range [l_count, r_count]
      include[0] = (n > 0) && !(0 >= l_count && 0 <= r_count);
      include[1] = (n > 1) && !(1 >= l_count && 1 <= r_count);
      include[2] = (n > 2) && !(2 >= l_count && 2 <= r_count);
      include[3] = (n > 3) && !(3 >= l_count && 3 <= r_count);
      include[4] = (n > 4) && !(4 >= l_count && 4 <= r_count);
      include[5] = (n > 5) && !(5 >= l_count && 5 <= r_count);
      include[6] = (n > 6) && !(6 >= l_count && 6 <= r_count);
      include[7] = (n > 7) && !(7 >= l_count && 7 <= r_count);
    end
  end
  
  // Combinational uniqueness check using parallel comparators
  always @(*) begin
    duplicate_found_comb = 1'b0;
    if (include[0] && include[1] && a[0] == a[1]) duplicate_found_comb = 1'b1;
    if (include[0] && include[2] && a[0] == a[2]) duplicate_found_comb = 1'b1;
    if (include[0] && include[3] && a[0] == a[3]) duplicate_found_comb = 1'b1;
    if (include[0] && include[4] && a[0] == a[4]) duplicate_found_comb = 1'b1;
    if (include[0] && include[5] && a[0] == a[5]) duplicate_found_comb = 1'b1;
    if (include[0] && include[6] && a[0] == a[6]) duplicate_found_comb = 1'b1;
    if (include[0] && include[7] && a[0] == a[7]) duplicate_found_comb = 1'b1;
    if (include[1] && include[2] && a[1] == a[2]) duplicate_found_comb = 1'b1;
    if (include[1] && include[3] && a[1] == a[3]) duplicate_found_comb = 1'b1;
    if (include[1] && include[4] && a[1] == a[4]) duplicate_found_comb = 1'b1;
    if (include[1] && include[5] && a[1] == a[5]) duplicate_found_comb = 1'b1;
    if (include[1] && include[6] && a[1] == a[6]) duplicate_found_comb = 1'b1;
    if (include[1] && include[7] && a[1] == a[7]) duplicate_found_comb = 1'b1;
    if (include[2] && include[3] && a[2] == a[3]) duplicate_found_comb = 1'b1;
    if (include[2] && include[4] && a[2] == a[4]) duplicate_found_comb = 1'b1;
    if (include[2] && include[5] && a[2] == a[5]) duplicate_found_comb = 1'b1;
    if (include[2] && include[6] && a[2] == a[6]) duplicate_found_comb = 1'b1;
    if (include[2] && include[7] && a[2] == a[7]) duplicate_found_comb = 1'b1;
    if (include[3] && include[4] && a[3] == a[4]) duplicate_found_comb = 1'b1;
    if (include[3] && include[5] && a[3] == a[5]) duplicate_found_comb = 1'b1;
    if (include[3] && include[6] && a[3] == a[6]) duplicate_found_comb = 1'b1;
    if (include[3] && include[7] && a[3] == a[7]) duplicate_found_comb = 1'b1;
    if (include[4] && include[5] && a[4] == a[5]) duplicate_found_comb = 1'b1;
    if (include[4] && include[6] && a[4] == a[6]) duplicate_found_comb = 1'b1;
    if (include[4] && include[7] && a[4] == a[7]) duplicate_found_comb = 1'b1;
    if (include[5] && include[6] && a[5] == a[6]) duplicate_found_comb = 1'b1;
    if (include[5] && include[7] && a[5] == a[7]) duplicate_found_comb = 1'b1;
    if (include[6] && include[7] && a[6] == a[7]) duplicate_found_comb = 1'b1;
  end
  
  // Register for duplicate found result
  always @(posedge clk) begin
    if (!rst_n) begin
      duplicate_found_reg <= 1'b0;
    end else begin
      duplicate_found_reg <= duplicate_found_comb;
    end
  end
  
  // State machine - sequential logic
  always @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
      min_size <= 4'b0;
      done <= 1'b0;
      l_count <= 3'b0;
      r_count <= 3'b0;
      first_cycle_calc <= 1'b0;
      check_all <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CHECK_UNIQUE;
            check_all <= 1'b1;
            min_size <= 4'b0; // Initialize to 0, will update if needed
            done <= 1'b0;
            first_cycle_calc <= 1'b0;
          end
        end
        
        CHECK_UNIQUE: begin
          state <= CALCULATE;
          check_all <= 1'b0; // Will be set to 0 in CALCULATE for subsegments
          first_cycle_calc <= 1'b1;
          l_count <= 3'b0;
          r_count <= 3'b0;
        end
        
        CALCULATE: begin
          if (first_cycle_calc) begin
            // First cycle: check if entire array is unique
            first_cycle_calc <= 1'b0;
            if (duplicate_found_reg == 1'b0) begin
              // Array is already unique
              min_size <= 4'b0;
              done <= 1'b1;
              state <= DONE;
            end else begin
              // Need to check subsegments
              state <= CALCULATE;
              // Initialize min_size to maximum possible (8)
              min_size <= 4'b1000;
            end
          end else begin
            // Regular cycle: process current subsegment
            if (duplicate_found_reg == 1'b0) begin
              // Current subsegment removal results in unique array
              if ((r_count - l_count + 1) < min_size) begin
                min_size <= (r_count - l_count + 1);
              end
            end
            
            // Generate next subsegment
            if (r_count < (n-1)) begin
              // Increase r
              r_count <= r_count + 1;
              state <= CALCULATE;
            end else if (l_count < (n-1)) begin
              // Move to next l
              l_count <= l_count + 1;
              r_count <= l_count + 1;
              state <= CALCULATE;
            end else begin
              // Done with all subsegments
              done <= 1'b1;
              state <= DONE;
            end
          end
        end
        
        DONE: begin
          // Stay in DONE state until reset
          done <= 1'b1;
        end
      endcase
    end
  end
  
endmodule