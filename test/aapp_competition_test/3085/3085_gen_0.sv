module bracket_converter(
  input clk,
  input rst_n,
  input start,
  input [7:0] input_str,
  output reg [511:0] output_buf,
  output reg [5:0] output_len,
  output reg done
);

  // Assumptions / Encoding:
  // - input_str is a bitmask of 8 characters (1 bit per char, LSB = index 0).
  // - 1'b1 represents '(', 1'b0 represents ')'.
  // - On each start pulse, a full 8-char balanced sequence is provided in input_str.
  // - Module generates ASCII "start,end:" header per matched pair, concatenated,
  //   using 0-based indices for positions [0..7].
  // - Shortest headers: indices 0-7 -> single decimal digit.

  // FSM states
  typedef enum logic [2:0] {
    S_IDLE   = 3'd0,
    S_LOAD   = 3'd1,
    S_PROC   = 3'd2,
    S_WRITE  = 3'd3,
    S_DONE   = 3'd4
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [2:0] idx;                 // current input index 0..7
  reg [2:0] stack [0:3];         // stack to hold indices, depth up to 4
  reg [2:0] sp;                  // stack pointer (number of valid entries)
  reg [2:0] cur_open;           // current open index for pair being written
  reg [2:0] cur_close;          // current close index for pair being written
  reg [1:0] write_step;         // 0..3 for 's','e',',',':' sequence
  reg [5:0] wr_ptr;             // byte write pointer into output_buf (0..63)

  // Extract bit (1='(',0=')') at position idx from input_str
  wire cur_bit = input_str[idx];

  // Combinational next state
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_LOAD;
      end

      S_LOAD: begin
        next_state = S_PROC;
      end

      S_PROC: begin
        // After finishing all 8 positions, move to DONE when no pending write
        if (idx == 3'd7 && write_step == 2'd0 && cur_bit == 1'b0 && sp == 3'd0)
          next_state = S_DONE;
        else if (write_step != 2'd0)
          next_state = S_WRITE;
        else
          next_state = S_PROC;
      end

      S_WRITE: begin
        if (write_step == 2'd3)
          next_state = (idx == 3'd7 && sp == 3'd0) ? S_DONE : S_PROC;
        else
          next_state = S_WRITE;
      end

      S_DONE: begin
        if (!start)
          next_state = S_IDLE;
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      idx        <= 3'd0;
      sp         <= 3'd0;
      cur_open   <= 3'd0;
      cur_close  <= 3'd0;
      write_step <= 2'd0;
      wr_ptr     <= 6'd0;
      output_buf <= {512{1'b0}};
      output_len <= 6'd0;
      done       <= 1'b0;
      for (i = 0; i < 4; i = i + 1) begin
        stack[i] <= 3'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done       <= 1'b0;
          if (start) begin
            // prepare for new conversion
            idx        <= 3'd0;
            sp         <= 3'd0;
            write_step <= 2'd0;
            wr_ptr     <= 6'd0;
            output_buf <= {512{1'b0}};
            output_len <= 6'd0;
          end
        end

        S_LOAD: begin
          // Nothing more than reset done in IDLE; transition to PROC
          done       <= 1'b0;
          write_step <= 2'd0;
        end

        S_PROC: begin
          done <= 1'b0;

          // If a write is pending (write_step != 0), stay in PROC's sequential
          // only when next_state keeps us here; otherwise handled in WRITE state.
          if (write_step == 2'd0) begin
            // Process current bit as parenthesis
            if (cur_bit == 1'b1) begin
              // '('
              stack[sp] <= idx;
              sp        <= sp + 3'd1;
              if (idx != 3'd7) begin
                idx <= idx + 3'd1;
              end
            end else begin
              // ')'
              if (sp != 3'd0) begin
                sp        <= sp - 3'd1;
                cur_open  <= stack[sp-1];
                cur_close <= idx;
                write_step <= 2'd1; // start writing header "start,end:"
              end
              if (idx != 3'd7) begin
                idx <= idx + 3'd1;
              end
            end
          end
        end

        S_WRITE: begin
          done <= 1'b0;
          // Write sequence: 's','e',',',':' using 0-based decimal digits single char
          case (write_step)
            2'd1: begin
              // 's'
              output_buf[(wr_ptr*8) +: 8] <= "s";
              wr_ptr     <= wr_ptr + 6'd1;
              write_step <= 2'd2;
            end
            2'd2: begin
              // 'e'
              output_buf[(wr_ptr*8) +: 8] <= "e";
              wr_ptr     <= wr_ptr + 6'd1;
              write_step <= 2'd3;
            end
            2'd3: begin
              // ',' then indices and ':' in minimal representation
              // For 0-7, single digit each: '0' + value
              // Sequence: start_index, ',', end_index, ':'
              // We'll pack all four bytes in this state for efficiency.
              output_buf[(wr_ptr*8) +: 8]     <= "0" + cur_open[2:0];
              output_buf[((wr_ptr+1)*8) +: 8] <= ",";
              output_buf[((wr_ptr+2)*8) +: 8] <= "0" + cur_close[2:0];
              output_buf[((wr_ptr+3)*8) +: 8] <= ":";
              wr_ptr     <= wr_ptr + 6'd4;
              write_step <= 2'd0; // done with this pair
            end
            default: begin
              write_step <= 2'd0;
            end
          endcase
        end

        S_DONE: begin
          done       <= 1'b1;
          output_len <= wr_ptr;
          // Wait for start to deassert (handled in next_state logic)
        end

        default: ;
      endcase
    end
  end

endmodule