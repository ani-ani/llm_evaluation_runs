module word_descrambler(
  input clk,
  input rst_n,
  input start,
  input [127:0] scrambled_str,
  input [63:0] dict_words [0:7],
  input [2:0] word_count,
  output reg [127:0] deciphered_str,
  output reg [1:0] status,
  output reg [3:0] output_length
);

  // FSM states
  typedef enum {
    IDLE,
    INIT,
    PREPROCESS,
    FIND_SPLITS,
    EVALUATE,
    DONE
  } state_t;

  state_t current_state, next_state;

  reg [7:0] scrambled_chars [0:15]; // Parsed input string
  reg [7:0] dict_chars [0:7][0:7];  // Parsed dictionary words
  reg [2:0] dict_lengths [0:7];     // Length of each dict word

  // Signatures: first, last, sorted_inner
  struct packed {
    reg [7:0] first;
    reg [7:0] last;
    reg [47:0] inner_sorted; // 6 chars
  } dict_sigs [0:7];

  // Preprocessing matrix: [start_pos][length] -> dict_idx or invalid
  reg [3:0] preproc_matrix [0:15][0:7]; // 4 bits can store 0-8 (invalid=9)
  reg is_valid_length [0:15][0:7];

  // Solution tracking
  reg [127:0] solution_str;
  reg [3:0] sol_length;
  reg has_one_solution;
  reg has_multiple;

  // Processing counters
  reg [4:0] pos;          // current position in scrambled_str (0-15)
  reg [3:0] cycles;       // cycle counter
  reg [3:0] prep_pos;     // Preprocess position
  reg [2:0] prep_len;     // Preprocess length
  reg [2:0] dict_idx;     // Current dict index

  // Substring extraction
  reg [7:0] test_chars [0:7];
  reg [47:0] test_inner_sorted;
  reg [7:0] test_first, test_last;
  reg [2:0] test_len;

  function automatic [47:0] sort_inner(input [7:0] inner [0:5], input [2:0] num_chars);
    reg [7:0] arr [0:5];
    integer i, j;
    reg [7:0] temp;
    begin
      for (i=0; i<6; i=i+1) arr[i] = (i < num_chars) ? inner[i] : 8'h0;
      for (i=0; i<5; i=i+1)
        for (j=0; j<5-i; j=j+1)
          if (arr[j] > arr[j+1]) begin
            temp = arr[j];
            arr[j] = arr[j+1];
            arr[j+1] = temp;
          end
      sort_inner = {arr[0], arr[1], arr[2], arr[3], arr[4], arr[5]};
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      deciphered_str <= 128'd0;
      status <= 2'b00;
      output_length <= 4'b0000;
      has_one_solution <= 1'b0;
      has_multiple <= 1'b0;
      solution_str <= 128'd0;
      sol_length <= 4'b0;
      cycles <= 4'd0;
      // Initialize other registers
    end else begin
      current_state <= next_state;
      cycles <= cycles + 4'd1;
    end
  end

  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: if (start) next_state = INIT;
      INIT: next_state = PREPROCESS;
      PREPROCESS: begin
        if (prep_pos == 16) next_state = FIND_SPLITS;
        else next_state = PREPROCESS; // Continue preprocessing
      end
      FIND_SPLITS: begin
        if (pos == 16 && has_multiple) next_state = EVALUATE;
        else if (pos == 16 && has_one_solution) next_state = EVALUATE;
        else if (pos == 16 || cycles >= 256) next_state = EVALUATE;
        else next_state = FIND_SPLITS;
      end
      EVALUATE: next_state = DONE;
      DONE: next_state = IDLE;
    endcase
  end

  always @(posedge clk) begin
    case (current_state)
      INIT: begin
        // Parse scrambled_str
        for (int i=0; i<16; i=i+1) scrambled_chars[i] = scrambled_str[i*8 +:8];
        // Parse dict_words and compute signatures
        for (int i=0; i<8; i=i+1) begin
          if ((i < word_count) || (word_count ==0)) begin
            for (int j=0; j<8; j=j+1) dict_chars[i][j] = dict_words[i][j*8 +:8];
            // Determine length (scan until 0 or 8)
            dict_lengths[i] = 3'd8;
            for (int j=0; j<8; j=j+1) begin
              if (dict_chars[i][j] == 8'h0) begin
                dict_lengths[i] = j;
                break;
              end
            end
            // Compute signature
            if (dict_lengths[i] == 1) begin
              dict_sigs[i].first = dict_chars[i][0];
              dict_sigs[i].last = dict_chars[i][0];
              dict_sigs[i].inner_sorted = 48'h0;
            end else if (dict_lengths[i] == 2) begin
              dict_sigs[i].first = dict_chars[i][0];
              dict_sigs[i].last = dict_chars[i][1];
              dict_sigs[i].inner_sorted = 48'h0;
            end else begin
              dict_sigs[i].first = dict_chars[i][0];
              dict_sigs[i].last = dict_chars[i][dict_lengths[i]-1];
              // Extract inner chars
              reg [7:0] inner_chars [0:5];
              integer idx;
              for (idx=0; idx<6; idx=idx+1) begin
                if (idx < (dict_lengths[i] - 2)) inner_chars[idx] = dict_chars[i][idx+1];
                else inner_chars[idx] = 8'h0;
              end
              dict_sigs[i].inner_sorted = sort_inner(inner_chars, dict_lengths[i]-2);
            end
          end else begin
            dict_lengths[i] = 3'd0;
            dict_sigs[i].first = 8'h0;
            dict_sigs[i].last = 8'h0;
            dict_sigs[i].inner_sorted = 48'h0;
          end
        end
        prep_pos <= 0;
        prep_len <= 0;
        cycles <= 0;
      end

      PREPROCESS: begin
        // For each start pos (prep_pos) and length (prep_len+1), compute substring signature
        // Length: l = prep_len + 1 (1-8)
        if (prep_pos < 16) begin
          integer l = prep_len + 1;
          integer max_pos = prep_pos + l;
          if (max_pos > 16) begin
            prep_len <= 0;
            prep_pos <= prep_pos + 1;
          end else begin
            // Extract test_chars[0:l-1]
            for (int j=0; j<8; j=j+1) test_chars[j] = (j < l) ? scrambled_chars[prep_pos + j] : 8'h0;
            test_len = l;
            test_first = test_chars[0];
            test_last = (l >=2) ? test_chars[l-1] : test_first;
            if (l == 1 || l == 2) begin
              test_inner_sorted = 48'h0;
            end else begin
              reg [7:0] inner [0:5];
              for (int k=0; k<6; k=k+1) inner[k] = (k < (l-2)) ? test_chars[1+k] : 8'h0;
              test_inner_sorted = sort_inner(inner, l-2);
            end
            // Find match in dict words with same length
            integer found = 0;
            integer match_idx = 0;
            for (dict_idx=0; dict_idx<word_count; dict_idx=dict_idx+1) begin
              if (dict_lengths[dict_idx] == l &&
                  dict_sigs[dict_idx].first == test_first &&
                  dict_sigs[dict_idx].last == test_last &&
                  dict_sigs[dict_idx].inner_sorted == test_inner_sorted) begin
                found = 1;
                match_idx = dict_idx;
              end
            end
            is_valid_length[prep_pos][l-1] = found;
            preproc_matrix[prep_pos][l-1] = match_idx;
            prep_len <= (prep_len == 7) ? 0 : prep_len + 1;
            if (prep_len == 7) prep_pos <= prep_pos + 1;
          end
        end
      end

      FIND_SPLITS: begin
        // Simplified version: Try first valid solution (prioritizing longest words)
        if (pos < 16) begin
          integer l;
          reg found = 0;
          for (l=8; l>=1; l=l-1) begin
            if (is_valid_length[pos][l-1]) begin
              found = 1;
              // Build solution string
              if (sol_length == 0) begin
                solution_str = {solution_str, dict_words[preproc_matrix[pos][l-1]]};
                sol_length = dict_lengths[preproc_matrix[pos][l-1]];
              end else begin
                // Add space and word
                solution_str = (solution_str << (64 - 8)) | {8'h20}
                              | (dict_words[preproc_matrix[pos][l-1]] << (64 - 8*(dict_lengths[preproc_matrix[pos][l-1]]+1)));
                sol_length = sol_length +1 + dict_lengths[preproc_matrix[pos][l-1]];
              end
              pos = pos + l;
              // If another solution is already found, mark ambiguous
              if (has_one_solution) has_multiple <= 1;
              has_one_solution <= 1;
              break;
            end
          end
          if (!found) begin
            // Dead end
            if (has_one_solution) has_multiple <= 1;
          end
        end
      end

      EVALUATE: begin
        if (has_multiple) begin
          status <= 2'b10;
        end else if (has_one_solution) begin
          status <= 2'b01;
          deciphered_str <= solution_str;
          output_length <= sol_length;
        end else begin
          status <= 2'b11;
        end
        next_state = DONE;
      end

      DONE: begin
        // Reset processing registers
        has_one_solution <= 0;
        has_multiple <= 0;
        cycles <= 0;
        sol_length <= 0;
        pos <= 0;
        solution_str <= 128'd0;
      end
    endcase
  end

endmodule