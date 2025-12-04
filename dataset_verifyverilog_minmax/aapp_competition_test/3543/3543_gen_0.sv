module autocorrect_min_keystrokes(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // start calculation
  input [7:0][39:0] dictionary, // 8 dictionary words (40 bits each: 8 chars * 5 bits/char)
  input [39:0] target_word, // word to type (40 bits: 8 chars * 5 bits/char)
  output reg [4:0] keystrokes, // minimum keystrokes required (max 31)
  output reg done // high when calculation complete
);

  // State machine for 3-cycle latency
  reg [1:0] state, state_next;
  localparam IDLE = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam OUTPUT = 2'b10;

  // Pipeline registers for 3-cycle latency
  reg [7:0] target_len, target_len_pipe1, target_len_pipe2;
  reg [63:0] target_bitvec, target_bitvec_pipe1, target_bitvec_pipe2;
  reg [7:0][39:0] dict_pipe1;
  reg start_sync, start_sync2;

  // Function to extract character from encoded word
  function [4:0] get_char(input [39:0] word, input [2:0] idx);
    integer shift;
    shift = idx * 5;
    get_char = word[shift +: 5];
  endfunction

  // Function to calculate word length (up to first 31 character)
  function [2:0] get_length(input [39:0] word);
    integer i;
    get_length = 3'd0;
    for (i = 0; i < 8; i = i + 1) begin
      if (get_char(word, i) != 5'd31) get_length = i + 1;
    end
  endfunction

  // Function to create bit vector for prefix matching
  function [63:0] get_bitvec(input [39:0] word, input [2:0] len);
    integer i;
    get_bitvec = 64'd0;
    for (i = 0; i < 8; i = i + 1) begin
      if (i < len && get_char(word, i) != 5'd31) begin
        get_bitvec[get_char(word, i)] = 1'b1;
      end
    end
  endfunction

  // Function to find common prefix length between two words
  function [2:0] common_prefix(input [39:0] w1, input [39:0] w2, input [2:0] max_len);
    integer i;
    common_prefix = 3'd0;
    for (i = 0; i < max_len; i = i + 1) begin
      if (get_char(w1, i) == get_char(w2, i) && get_char(w1, i) != 5'd31) begin
        common_prefix = i + 1;
      end else begin
        i = max_len; // Break loop
      end
    end
  endfunction

  // Sequential logic with reset
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      keystrokes <= 5'd0;
      done <= 1'b0;
      target_len <= 3'd0;
      target_bitvec <= 64'd0;
      dict_pipe1 <= '0;
      start_sync <= 1'b0;
      start_sync2 <= 1'b0;
      target_len_pipe1 <= 3'd0;
      target_len_pipe2 <= 3'd0;
      target_bitvec_pipe1 <= 64'd0;
      target_bitvec_pipe2 <= 64'd0;
    end else begin
      // Pipeline registers
      target_len <= get_length(target_word);
      target_bitvec <= get_bitvec(target_word, get_length(target_word));
      start_sync <= start;
      start_sync2 <= start_sync;
      
      if (start_sync2) begin
        dict_pipe1 <= dictionary;
        target_len_pipe1 <= target_len;
        target_len_pipe2 <= target_len_pipe1;
        target_bitvec_pipe1 <= target_bitvec;
        target_bitvec_pipe2 <= target_bitvec_pipe1;
      end
      
      // State machine
      case (state)
        IDLE: begin
          keystrokes <= 5'd0;
          done <= 1'b0;
          if (start_sync) begin
            state <= PROCESSING;
          end
        end
        
        PROCESSING: begin
          state <= OUTPUT;
          // Compute minimum keystrokes
          if (start_sync2) begin
            reg [4:0] min_cost;
            reg [2:0] target_len_local;
            reg [63:0] target_bitvec_local;
            reg [7:0][39:0] dict_local;
            integer i, j, prefix_len, dict_len;
            
            target_len_local = target_len_pipe2;
            target_bitvec_local = target_bitvec_pipe2;
            dict_local = dict_pipe1;
            min_cost = target_len_local; // Default: type all characters
            
            // Check each dictionary word
            for (i = 0; i < 8; i = i + 1) begin
              dict_len = get_length(dict_local[i]);
              
              // Check for prefix overlap
              prefix_len = common_prefix(dict_local[i], target_word, (target_len_local < dict_len) ? target_len_local : dict_len);
              
              if (prefix_len > 0) begin
                // Calculate cost: TAB (1) + delete to prefix + type remaining
                reg [4:0] autocorrect_cost;
                autocorrect_cost = 1 + prefix_len + (dict_len - prefix_len);
                
                if (autocorrect_cost < min_cost) begin
                  min_cost = autocorrect_cost;
                end
              end
            end
            
            keystrokes <= min_cost;
          end
        end
        
        OUTPUT: begin
          done <= 1'b1;
          state <= IDLE;
        end
        
        default: state <= IDLE;
      endcase
    end
  end
endmodule