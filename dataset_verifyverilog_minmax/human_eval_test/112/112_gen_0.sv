module string_filter_palindrome(
  input clk,
  input rst_n,
  input start,
  input [7:0] s_chars [7:0],
  input [7:0] c_chars [7:0],
  input [2:0] s_len,
  input [2:0] c_len,
  output reg [7:0] result_chars [7:0],
  output reg [2:0] result_len,
  output reg is_palindrome,
  output reg done
);

  // State machine states
  parameter IDLE = 4'h0;
  parameter ST1  = 4'h1;  // Filtering
  parameter ST2  = 4'h2;  // Palindrome step 0
  parameter ST3  = 4'h3;  // Palindrome step 1
  parameter ST4  = 4'h4;  // Palindrome step 2
  parameter ST5  = 4'h5;  // Palindrome step 3
  parameter ST6  = 4'h6;  // Palindrome step 4
  parameter ST7  = 4'h7;  // Palindrome step 5
  parameter ST8  = 4'h8;  // Palindrome step 6
  parameter ST9  = 4'h9;  // Palindrome step 7 (final)

  // State register
  reg [3:0] state, next_state;

  // Input registers for stable values during processing
  reg [7:0] s_chars_reg [7:0];
  reg [7:0] c_chars_reg [7:0];
  reg [2:0] s_len_reg, c_len_reg;

  // Palindrome check variables
  reg [2:0] pal_index;
  reg palindrome;

  // Combinational outputs for filtering
  wire [7:0] keep_flags;
  wire [2:0] result_len_temp;
  wire [7:0] result_chars_temp [7:0];

  // Always block for state machine
  always @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      is_palindrome <= 1'b0;
      result_len <= 3'b0;
      for (int i = 0; i < 8; i++) begin
        result_chars[i] <= 8'h00;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          if (start) begin
            // Latch inputs when start pulse is detected
            for (int i = 0; i < 8; i++) begin
              s_chars_reg[i] <= s_chars[i];
              c_chars_reg[i] <= c_chars[i];
            end
            s_len_reg <= s_len;
            c_len_reg <= c_len;
          end
        end

        ST1: begin
          // Filter results from combinational logic
          result_len <= result_len_temp;
          for (int i = 0; i < 8; i++) begin
            result_chars[i] <= result_chars_temp[i];
          end
          // Initialize palindrome checking
          palindrome <= 1'b1;
          pal_index <= 3'b0;
        end

        ST2: begin
          pal_index <= 3'b1;
          if (result_len > 0 && 3'b0 < result_len[2:1]) begin
            if (result_chars[0] != result_chars[result_len - 1]) 
              palindrome <= 1'b0;
          end
        end

        ST3: begin
          pal_index <= 3'b10;
          if (3'b1 < result_len[2:1]) begin
            if (result_chars[1] != result_chars[result_len - 2]) 
              palindrome <= 1'b0;
          end
        end

        ST4: begin
          pal_index <= 3'b11;
          if (3'b10 < result_len[2:1]) begin
            if (result_chars[2] != result_chars[result_len - 3]) 
              palindrome <= 1'b0;
          end
        end

        ST5: begin
          pal_index <= 3'b100;
          if (3'b11 < result_len[2:1]) begin
            if (result_chars[3] != result_chars[result_len - 4]) 
              palindrome <= 1'b0;
          end
        end

        ST6: begin
          pal_index <= 3'b101;
          if (3'b100 < result_len[2:1]) begin
            if (result_chars[4] != result_chars[result_len - 5]) 
              palindrome <= 1'b0;
          end
        end

        ST7: begin
          pal_index <= 3'b110;
          if (3'b101 < result_len[2:1]) begin
            if (result_chars[5] != result_chars[result_len - 6]) 
              palindrome <= 1'b0;
          end
        end

        ST8: begin
          pal_index <= 3'b111;
          if (3'b110 < result_len[2:1]) begin
            if (result_chars[6] != result_chars[result_len - 7]) 
              palindrome <= 1'b0;
          end
        end

        ST9: begin
          // Final state - set done flag and palindrome result
          done <= 1'b1;
          is_palindrome <= palindrome;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    case (state)
      IDLE:   next_state = (start) ? ST1 : IDLE;
      ST1:    next_state = ST2;
      ST2:    next_state = ST3;
      ST3:    next_state = ST4;
      ST4:    next_state = ST5;
      ST5:    next_state = ST6;
      ST6:    next_state = ST7;
      ST7:    next_state = ST8;
      ST8:    next_state = ST9;
      ST9:    next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Combinational logic for filtering (executed in ST1 state)
  always @(*) begin
    if (state == ST1) begin
      // Compute keep flags for each position
      for (int i = 0; i < 8; i++) begin
        keep_flags[i] = 1'b1;
        for (int j = 0; j < 8; j++) begin
          if (s_chars_reg[i] == c_chars_reg[j]) begin
            keep_flags[i] = 1'b0;
            break;
          end
        end
      end

      // Count total characters to keep
      result_len_temp = 3'b0;
      for (int i = 0; i < 8; i++) begin
        result_len_temp = result_len_temp + keep_flags[i];
      end

      // Pack filtered characters left-aligned
      for (int i = 0; i < 8; i++) begin
        result_chars_temp[i] = 8'h00;
      end

      integer idx;
      idx = 0;
      for (int i = 0; i < 8; i++) begin
        if (keep_flags[i]) begin
          if (idx < 8) begin
            result_chars_temp[idx] = s_chars_reg[i];
            idx = idx + 1;
          end
        end
      end
    end
  end
endmodule