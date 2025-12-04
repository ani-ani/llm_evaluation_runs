module cfg_substring_matcher(
  input clk,
  input rst_n,
  input start,
  input [263:0] rules, // 8 rules * 33 bits
  input [95:0] text_line, // 16 chars * 6 bits
  output reg [95:0] longest_substr,
  output reg valid,
  output reg done 
);

  // Constants
  localparam NUM_RULES = 8;
  localparam RULE_WIDTH = 33;
  localparam TEXT_LEN = 16;
  localparam CHAR_WIDTH = 6;
  localparam MAX_DERIV_STEPS = 16;
  localparam TOTAL_SUBSTR = (TEXT_LEN * (TEXT_LEN + 1)) / 2; // 136
  
  // State machine states
  localparam IDLE = 3'b000;
  localparam INIT = 3'b001;
  localparam PROCESS = 3'b010;
  localparam CHECK = 3'b011;
  localparam NEXT_SUBSTR = 3'b100;
  localparam FINISH = 3'b101;
  
  // Rule representation: [32:0] per rule
  // bits[32:28]: head (5 bits)
  // bits[27:21]: sym1 (7 bits: [6]=var flag, [5:0]=index)
  // bits[20:14]: sym2 (7 bits)
  // bits[13:7]: sym3 (7 bits)
  // bits[6:0]: sym4 (7 bits)
  
  // Text character representation: 6 bits per char
  // 0-25: 'a'-'z', 26: space
  
  // Sentential form representation
  // Array of 16 symbols, each symbol is 7 bits
  // 6 bits: symbol value, 1 bit: is_variable flag
  typedef logic [6:0] symbol_t;
  typedef symbol_t sentential_form_t [0:15];
  
  // State machine variables
  reg [2:0] state, next_state;
  reg [7:0] substring_count; // 0-135
  reg [3:0] curr_length; // 1-16
  reg [3:0] curr_start; // 0-15
  reg [4:0] deriv_step; // 0-16
  reg [7:0] rules_mem [0:7]; // Store rules
  
  // Matching variables
  sentential_form_t stack [0:15]; // Stack for DFS
  reg [4:0] stack_depth;
  reg [3:0] text_index; // Current position in text
  reg [3:0] form_index; // Current position in sentential form
  reg match_success;
  
  // Substring variables
  reg [3:0] substr_start, substr_end;
  reg [95:0] current_substr;
  
  // Initialize rules memory
  always @(posedge clk) begin
    if (!rst_n) begin
      for (int i = 0; i < NUM_RULES; i++) begin
        rules_mem[i] <= 8'd0;
      end
    end else if (start) begin
      for (int i = 0; i < NUM_RULES; i++) begin
        rules_mem[i] <= rules[i*33 +: 33];
      end
    end
  end
  
  // State machine
  always @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end
  
  always @(*) begin
    next_state = state;
    
    case (state)
      IDLE: begin
        if (start) next_state = INIT;
      end
      
      INIT: begin
        next_state = PROCESS;
      end
      
      PROCESS: begin
        if (deriv_step < MAX_DERIV_STEPS) begin
          next_state = CHECK;
        end else begin
          next_state = NEXT_SUBSTR;
        end
      end
      
      CHECK: begin
        next_state = PROCESS;
      end
      
      NEXT_SUBSTR: begin
        if (substring_count < TOTAL_SUBSTR-1) begin
          next_state = PROCESS;
        end else begin
          next_state = FINISH;
        end
      end
      
      FINISH: begin
        next_state = IDLE;
      end
      
      default: next_state = IDLE;
    endcase
  end
  
  // Main processing logic
  always @(posedge clk) begin
    if (!rst_n) begin
      substring_count <= 8'd0;
      curr_length <= 4'd0;
      curr_start <= 4'd0;
      deriv_step <= 5'd0;
      valid <= 1'b0;
      done <= 1'b0;
      longest_substr <= 96'd0;
      substr_start <= 4'd0;
      substr_end <= 4'd0;
      current_substr <= 96'd0;
    end else begin
      case (state)
        IDLE: begin
          // Outputs already reset
        end
        
        INIT: begin
          substring_count <= 8'd0;
          curr_length <= 4'd16; // Start with longest
          curr_start <= 4'd0;
          valid <= 1'b0;
          done <= 1'b0;
          // Get first substring
          substr_start <= 4'd0;
          substr_end <= 4'd15;
          current_substr <= text_line;
        end
        
        PROCESS: begin
          // Initialize for new substring or new deriv step
          if (deriv_step == 5'd0) begin
            // Initialize sentential form with start variable
            stack[0] <= {<<{rules_mem[0][32:28], 7'd0, 7'd0, 7'd0, 7'd0}};
            stack_depth <= 5'd1;
            text_index <= substr_start;
            form_index <= 4'd0;
            match_success <= 1'b1;
          end
          
          deriv_step <= deriv_step + 1;
        end
        
        CHECK: begin
          // Perform one derivation step
          if (match_success && stack_depth > 0) begin
            symbol_t current_symbol;
            current_symbol = stack[stack_depth-1][form_index];
            
            if (current_symbol[6]) begin // Is variable
              // Find matching rules
              reg rule_found;
              rule_found = 1'b0;
              for (int i = 0; i < NUM_RULES && !rule_found; i++) begin
                if (rules_mem[i][32:28] == current_symbol[5:0]) begin
                  // Replace with production
                  for (int j = 0; j < 4; j++) begin
                    stack[stack_depth-1][form_index + j] <= rules_mem[i][21 - j*7 -: 7];
                  end
                  // Extend stack if needed
                  if (stack_depth < 16) begin
                    stack[stack_depth] <= '{default: '0};
                  end
                  stack_depth <= stack_depth + 3; // Remove variable, add 4 symbols
                  rule_found = 1'b1;
                end
              end
              if (!rule_found) begin
                match_success <= 1'b0;
              end
            end else begin
              // Check terminal against text
              if (text_index <= substr_end) begin
                if (text_line[text_index*6 +: 6] == current_symbol[5:0]) begin
                  form_index <= form_index + 1;
                  text_index <= text_index + 1;
                end else begin
                  match_success <= 1'b0;
                end
              end else begin
                match_success <= 1'b0;
              end
            end
            
            // Check if derivation complete
            if (form_index >= 4 && stack_depth == 1 && text_index > substr_end) begin
              match_success <= 1'b1;
            end
          end
        end
        
        NEXT_SUBSTR: begin
          if (match_success) begin
            // Found a match - output it
            valid <= 1'b1;
            for (int i = 0; i < TEXT_LEN; i++) begin
              if (i >= substr_start && i <= substr_end) begin
                longest_substr[i*6 +: 6] <= text_line[i*6 +: 6];
              end else begin
                longest_substr[i*6 +: 6] <= 6'd0;
              end
            end
            done <= 1'b1;
            next_state <= FINISH;
          end else begin
            // Move to next substring
            substring_count <= substring_count + 1;
            deriv_step <= 5'd0;
            
            // Calculate next substring
            if (curr_start < (16 - curr_length)) begin
              curr_start <= curr_start + 1;
            end else begin
              curr_length <= curr_length - 1;
              curr_start <= 4'd0;
            end
            
            substr_start <= curr_start;
            substr_end <= curr_start + curr_length - 1;
            // Extract current substring
            for (int i = 0; i < TEXT_LEN; i++) begin
              if (i >= substr_start && i <= substr_end) begin
                current_substr[i*6 +: 6] <= text_line[i*6 +: 6];
              end else begin
                current_substr[i*6 +: 6] <= 6'd0;
              end
            end
          end
        end
        
        FINISH: begin
          done <= 1'b1;
        end
      endcase
    end
  end
endmodule