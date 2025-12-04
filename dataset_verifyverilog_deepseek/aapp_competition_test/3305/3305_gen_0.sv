module almost_palindrome_counter (
  input clk,
  input rst_n,
  input start,
  input [5:0] str_len,
  input [2:0] L,
  input [2:0] R,
  input [7:0][4:0] char_array,
  output reg [5:0] count,
  output reg done
);

  reg [3:0] step_counter;
  reg [2:0] seg_start, seg_end;
  reg [2:0] sub_start_reg [0:35];
  reg [2:0] sub_end_reg [0:35];
  reg [5:0] total_substrings;
  reg [35:0] palin_flag;
  reg [35:0] almost_palin_flag;
  wire [35:0] palin_flag_comb;
  wire [35:0] almost_palin_flag_comb;
  reg [5:0] count_reg;
  wire [5:0] count_comb;

  // Step counter FSM
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      step_counter <= 0;
      done <= 0;
      count <= 0;
      palin_flag <= 0;
      almost_palin_flag <= 0;
      total_substrings <= 0;
      seg_start <= 0;
      seg_end <= 0;
      count_reg <= 0;
    end else begin
      case (step_counter)
        0: begin
          if (start) begin
            seg_start <= L - 3'd1;
            seg_end <= R - 3'd1;
            step_counter <= 1;
            done <= 0;
            count <= 0;
          end
        end
        1: begin
          // Store substring indices
          step_counter <= 2;
        end
        2: begin
          // Latch palindrome flags
          palin_flag <= palin_flag_comb;
          step_counter <= 3;
        end
        3: begin
          // Latch almost_palindrome flags
          almost_palin_flag <= almost_palin_flag_comb;
          step_counter <= 4;
        end
        4: begin
          // Accumulate count
          count_reg <= count_comb;
          step_counter <= 5;
        end
        5: begin
          done <= 1;
          count <= count_reg;
          if (start) begin
            step_counter <= 1;
            done <= 0;
          end
        end
        default: step_counter <= 0;
      endcase
    end
  end

  // Cycle 1: Precompute substring indices
  always_ff @(posedge clk) begin
    if (step_counter == 0 && start) begin
      total_substrings <= 0;
    end else if (step_counter == 1) begin
      automatic int idx = 0;
      for (int i=seg_start; i<=seg_end; i++) begin
        for (int j=i; j<=seg_end; j++) begin
          if (idx < 36) begin
            sub_start_reg[idx] <= i;
            sub_end_reg[idx] <= j;
            idx = idx + 1;
          end
        end
      end
      total_substrings <= idx;
    end
  end

  // Cycle 2: Palindrome check
  generate
    for (genvar m=0; m<36; m++) begin : palin_gen
      assign palin_flag_comb[m] = (m < total_substrings) ? check_palindrome(sub_start_reg[m], sub_end_reg[m]) : 1'b0;

      function automatic logic check_palindrome(input [2:0] start_idx, end_idx);
        automatic int len = end_idx - start_idx + 1;
        automatic logic ret = 1'b1;
        for (int k=0; k<(len+1)/2; k++) begin
          if (char_array[start_idx + k] != char_array[end_idx - k]) begin
            ret = 1'b0;
          end
        end
        return ret;
      endfunction
    end
  endgenerate

  // Cycle 3: Almost palindrome check
  generate
    for (genvar m=0; m<36; m++) begin : almost_palin_gen
      assign almost_palin_flag_comb[m] = (m < total_substrings && !palin_flag[m]) ? check_almost_palindrome(sub_start_reg[m], sub_end_reg[m]) : 1'b0;

      function automatic logic check_almost_palindrome(input [2:0] start_idx, end_idx);
        automatic int len = end_idx - start_idx + 1;
        automatic logic ret = 1'b0;
        automatic bit [4:0] s[0:7];
        // Extract substring
        for (int kk=0; kk<8; kk++) begin
          s[kk] = (kk < len) ? char_array[start_idx + kk] : 0;
        end
        // Check all swaps
        for (int x=0; x<len; x++) begin
          for (int y=x+1; y<len; y++) begin
            automatic bit [4:0] swapped_s[0:7];
            // Create swapped string
            for (int k=0; k<len; k++) begin
              if (k == x) swapped_s[k] = s[y];
              else if (k == y) swapped_s[k] = s[x];
              else swapped_s[k] = s[k];
            end
            // Check if swapped is palindrome
            automatic logic is_palin = 1'b1;
            for (int k=0; k<(len+1)/2; k++) begin
              if (swapped_s[k] != swapped_s[len-1-k]) begin
                is_palin = 1'b0;
              end
            end
            if (is_palin) ret = 1'b1;
          end
        end
        return ret;
      endfunction
    end
  endgenerate

  // Cycle 4: Count accumulation
  assign count_comb = count_substrings(palin_flag | almost_palin_flag);

  function automatic [5:0] count_substrings(input [35:0] flags);
    automatic [5:0] cnt = 0;
    for (int i=0; i<36; i++) begin
      if (i < total_substrings) begin
        cnt += flags[i];
      end
    end
    return cnt;
  endfunction

endmodule