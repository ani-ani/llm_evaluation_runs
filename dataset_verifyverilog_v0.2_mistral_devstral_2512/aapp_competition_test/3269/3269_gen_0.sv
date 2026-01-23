module digit_distance_sum (
  input clk,
  input rst_n,
  input start,
  input [31:0] A,
  input [31:0] B,
  output reg [31:0] result,
  output reg done
);

  // Parameters
  localparam IDLE = 3'b000;
  localparam SETUP = 3'b001;
  localparam COUNT_LOOP = 3'b010;
  localparam COMPUTE_DIST = 3'b011;
  localparam DONE = 3'b100;
  
  localparam MAX_ITER = 10000;
  localparam MODULUS = 32'h3B9ACA07;
  
  // State machine
  reg [2:0] state = IDLE;
  
  // Digit counts (8 positions, 10 digits each)
  reg [19:0] digit_counts [0:7][0:9];
  
  // Loop counters
  reg [31:0] current_num;
  reg [2:0] pos;
  reg [3:0] d1, d2;
  reg [31:0] iter_count;
  
  // Intermediate results
  reg [31:0] total_sum;
  reg [31:0] contribution;
  
  // Helper function for modulo addition
  function [31:0] mod_add;
    input [31:0] a, b;
    begin
      mod_add = (a + b) % MODULUS;
    end
  endfunction
  
  // Helper function for modulo multiplication
  function [31:0] mod_mult;
    input [31:0] a, b;
    begin
      mod_mult = (a * b) % MODULUS;
    end
  endfunction
  
  // Extract digit at position pos from number num
  function [3:0] get_digit;
    input [31:0] num;
    input [2:0] pos;
    begin
      get_digit = (num / (10 ** pos)) % 10;
    end
  endfunction
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      total_sum <= 0;
      iter_count <= 0;
      pos <= 0;
      d1 <= 0;
      d2 <= 0;
      current_num <= 0;
      for (int i = 0; i < 8; i++) begin
        for (int j = 0; j < 10; j++) begin
          digit_counts[i][j] <= 0;
        end
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SETUP;
            done <= 0;
            result <= 0;
            total_sum <= 0;
            iter_count <= 0;
            pos <= 0;
            d1 <= 0;
            d2 <= 0;
            current_num <= A;
            // Initialize digit counts
            for (int i = 0; i < 8; i++) begin
              for (int j = 0; j < 10; j++) begin
                digit_counts[i][j] <= 0;
              end
            end
          end
        end
        
        SETUP: begin
          state <= COUNT_LOOP;
        end
        
        COUNT_LOOP: begin
          if (iter_count < MAX_ITER && current_num <= B) begin
            // Count digits for current number
            for (int i = 0; i < 8; i++) begin
              digit_counts[i][get_digit(current_num, i)] <= digit_counts[i][get_digit(current_num, i)] + 1;
            end
            
            current_num <= current_num + 1;
            iter_count <= iter_count + 1;
          end else begin
            state <= COMPUTE_DIST;
            pos <= 0;
            d1 <= 0;
            d2 <= 0;
            contribution <= 0;
          end
        end
        
        COMPUTE_DIST: begin
          if (pos < 8) begin
            if (d1 < 10) begin
              if (d2 < 10) begin
                // Compute contribution for this digit pair
                contribution <= mod_add(contribution, mod_mult(mod_mult(digit_counts[pos][d1], digit_counts[pos][d2]), (d1 > d2) ? (d1 - d2) : (d2 - d1)));
                d2 <= d2 + 1;
              end else begin
                d2 <= 0;
                d1 <= d1 + 1;
              end
            end else begin
              // Add position contribution to total
              total_sum <= mod_add(total_sum, contribution);
              contribution <= 0;
              d1 <= 0;
              pos <= pos + 1;
            end
          end else begin
            state <= DONE;
            result <= total_sum;
            done <= 1;
          end
        end
        
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule