module palindrome_parts(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [15:0][7:0] s,
  output reg [3:0] k,
  output [15:0][7:0] parts,
  output reg done
);

  // State machine states
  localparam IDLE = 0, COUNT = 1, CALC_K = 2, BUILD = 3, DONE = 4;
  
  // Internal registers
  reg [3:0] state, next_state;
  reg [6:0] overall_counter;
  reg [4:0] count_index;
  reg [3:0] candidate;
  reg [3:0] m;
  reg [5:0] freq_count [0:15];
  reg [7:0] distinct_chars [0:15];
  reg [3:0] distinct_count;
  reg [7:0] centers [0:15];
  reg [3:0] m_reg;
  reg [7:0] left [0:7];
  reg [4:0] left_index;
  reg [7:0] full_string [0:15];
  reg [7:0] parts_reg [0:15];
  reg [4:0] build_index;
  reg [3:0] k_result;
  reg done_reg;
  reg [3:0] L;
  
  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      overall_counter <= 0;
      count_index <= 0;
      candidate <= 0;
      distinct_count <= 0;
      m_reg <= 0;
      left_index <= 0;
      build_index <= 0;
      k_result <= 0;
      done_reg <= 0;
      L <= 0;
      for (int i = 0; i < 16; i++) begin
        freq_count[i] <= 0;
        parts_reg[i] <= 0;
        full_string[i] <= 0;
        centers[i] <= 0;
        left[i] <= 0;
        distinct_chars[i] <= 0;
      end
      k <= 0;
      done <= 0;
    end else begin
      overall_counter <= overall_counter + 1;
      
      case (state)
        IDLE: begin
          if (start) begin
            state <= COUNT;
            count_index <= 0;
            distinct_count <= 0;
            for (int i = 0; i < 16; i++) begin
              freq_count[i] <= 0;
            end
          end
        end
        
        COUNT: begin
          if (count_index < n) begin
            // Linear search for character in distinct_chars
            int found;
            found = 0;
            for (int j = 0; j < distinct_count; j++) begin
              if (distinct_chars[j] == s[count_index]) begin
                freq_count[j] <= freq_count[j] + 1;
                found = 1;
              end
            end
            if (!found && distinct_count < 16) begin
              distinct_chars[distinct_count] <= s[count_index];
              freq_count[distinct_count] <= 1;
              distinct_count <= distinct_count + 1;
            end
            count_index <= count_index + 1;
          end else begin
            state <= CALC_K;
            candidate <= 0; // will be set in CALC_K
          end
        end
        
        CALC_K: begin
          // Compute m - number of characters with odd frequency
          m <= 0;
          for (int i = 0; i < distinct_count; i++) begin
            if (freq_count[i][0] == 1) begin // odd frequency
              m <= m + 1;
            end
          end
          
          // Find smallest k >= m that divides n
          if (candidate >= n) begin
            k_result <= n;
            state <= BUILD;
          end else if (n % candidate == 0 && candidate >= m) begin
            k_result <= candidate;
            state <= BUILD;
          end else begin
            candidate <= candidate + 1;
          end
        end
        
        BUILD: begin
          // Build centers array
          int centers_idx;
          centers_idx = 0;
          m_reg <= 0;
          for (int i = 0; i < distinct_count; i++) begin
            if (freq_count[i][0] == 1) begin
              centers[centers_idx] <= distinct_chars[i];
              centers_idx++;
            end
          end
          m_reg <= centers_idx;
          
          // Build left array
          left_index <= 0;
          for (int i = 0; i < distinct_count; i++) begin
            for (int j = 0; j < freq_count[i]/2; j++) begin
              left[left_index] <= distinct_chars[i];
              left_index <= left_index + 1;
            end
          end
          
          // Build full string
          L <= n / k_result;
          int full_idx;
          int left_base;
          int pal_idx;
          int pos_in_pal;
          
          full_idx = 0;
          left_base = 0;
          
          for (pal_idx = 0; pal_idx < k_result; pal_idx++) begin
            if (pal_idx < m_reg) begin // odd-length palindrome
              // Left half
              for (pos_in_pal = 0; pos_in_pal < (L-1)/2; pos_in_pal++) begin
                full_string[full_idx] <= left[left_base + pos_in_pal];
                full_idx++;
              end
              // Center
              full_string[full_idx] <= centers[pal_idx];
              full_idx++;
              // Right half
              for (pos_in_pal = 0; pos_in_pal < (L-1)/2; pos_in_pal++) begin
                full_string[full_idx] <= left[left_base + (L-1)/2 - 1 - pos_in_pal];
                full_idx++;
              end
              left_base = left_base + (L-1)/2;
            end else begin // even-length palindrome
              // Left half
              for (pos_in_pal = 0; pos_in_pal < L/2; pos_in_pal++) begin
                full_string[full_idx] <= left[left_base + pos_in_pal];
                full_idx++;
              end
              // Right half
              for (pos_in_pal = 0; pos_in_pal < L/2; pos_in_pal++) begin
                full_string[full_idx] <= left[left_base + L/2 - 1 - pos_in_pal];
                full_idx++;
              end
              left_base = left_base + L/2;
            end
          end
          
          state <= DONE;
        end
        
        DONE: begin
          if (overall_counter == 99) begin
            done_reg <= 1;
            k <= k_result;
            for (int i = 0; i < 16; i++) begin
              if (i < n) begin
                parts_reg[i] <= full_string[i];
              end else begin
                parts_reg[i] <= 0;
              end
            end
            state <= IDLE;
          end else begin
            done_reg <= 0;
          end
        end
        
        default: state <= IDLE;
      endcase
    end
  end
  
  // Assign outputs
  assign parts = parts_reg;
  always @(posedge clk) begin
    done <= done_reg;
  end
  
endmodule