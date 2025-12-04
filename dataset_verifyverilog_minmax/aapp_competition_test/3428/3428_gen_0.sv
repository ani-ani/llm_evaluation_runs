module gcd_distinct_count(
  input clk, // system clock
  input rst_n, // active-low reset
  input start, // start computation
  input [2:0] n, // sequence length (1-8)
  input [7:0][15:0] a, // 8-element sequence (16-bit values)
  output reg [5:0] count, // number of distinct GCDs
  output reg done // high when computation completes
);

  // State definitions
  localparam IDLE = 2'b00;
  localparam COMPUTE = 2'b01;
  localparam COUNT = 2'b10;

  // FSM state
  reg [1:0] state;

  // Table storage: 8x8 GCD table with valid flags
  reg [7:0][7:0] valid_table;
  reg [7:0][7:0][15:0] gcd_table;

  // Current computation indices
  reg [2:0] current_i;
  reg [2:0] current_j;

  // Euclidean algorithm state
  reg [15:0] euclid_x;
  reg [15:0] euclid_y;
  reg [3:0] euclid_count;
  reg euclid_done;

  // Count state for distinct GCD detection
  reg [15:0] distinct_gcds[31:0]; // Store up to 36 distinct GCDs
  reg [5:0] distinct_count_temp;
  reg [5:0] distinct_index;
  reg found_match;

  // FSM state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      count <= 6'b0;
      current_i <= 3'b0;
      current_j <= 3'b0;
      euclid_x <= 16'b0;
      euclid_y <= 16'b0;
      euclid_count <= 4'b0;
      euclid_done <= 1'b0;
      valid_table <= 64'b0;
      distinct_count_temp <= 6'b0;
      distinct_index <= 6'b0;
      found_match <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          count <= 6'b0;
          if (start) begin
            state <= COMPUTE;
            current_i <= 3'b0;
            current_j <= 3'b0;
            // Initialize table
            valid_table <= 64'b0;
            // Initialize Euclidean algorithm state
            euclid_count <= 4'b0;
            euclid_done <= 1'b0;
          end
        end

        COMPUTE: begin
          if (current_i < n) begin
            if (current_j >= current_i && current_j < n) begin
              if (current_j == current_i) begin
                // Base case: GCD of single element
                gcd_table[current_i][current_j] <= a[current_i];
                valid_table[current_i][current_j] <= 1'b1;
                current_j <= current_j + 1;
              end else begin
                // Compute GCD of sequence from current_i to current_j
                if (!euclid_done) begin
                  if (euclid_count == 0) begin
                    // Initialize Euclidean algorithm
                    euclid_x <= gcd_table[current_i][current_j-1];
                    euclid_y <= a[current_j];
                    euclid_count <= euclid_count + 1;
                  end else begin
                    if (euclid_y != 0) begin
                      euclid_x <= euclid_y;
                      euclid_y <= euclid_x % euclid_y;
                      euclid_count <= euclid_count + 1;
                    end else begin
                      euclid_done <= 1'b1;
                      euclid_count <= 0;
                    end
                  end
                end else begin
                  // Store result and move to next
                  gcd_table[current_i][current_j] <= euclid_x;
                  valid_table[current_i][current_j] <= 1'b1;
                  current_j <= current_j + 1;
                  euclid_done <= 1'b0;
                  euclid_count <= 4'b0;
                end
              end
            end else begin
              // Move to next row
              current_i <= current_i + 1;
              current_j <= current_i;
            end
          end else begin
            // All GCDs computed, move to COUNT state
            state <= COUNT;
            distinct_count_temp <= 6'b0;
            distinct_index <= 6'b0;
          end
        end

        COUNT: begin
          if (distinct_index < 6'd36) begin
            // Check if current GCD is already in distinct list
            found_match <= 1'b0;
            for (int k = 0; k < 36; k = k + 1) begin
              if (k < distinct_count_temp) begin
                if (gcd_table[distinct_index/8][distinct_index%8] == distinct_gcds[k]) begin
                  found_match <= 1'b1;
                end
              end
            end
            
            if (!found_match) begin
              // Add to distinct list
              distinct_gcds[distinct_count_temp] <= gcd_table[distinct_index/8][distinct_index%8];
              distinct_count_temp <= distinct_count_temp + 1;
            end
            distinct_index <= distinct_index + 1;
          end else begin
            // Done counting
            count <= distinct_count_temp;
            done <= 1'b1;
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule