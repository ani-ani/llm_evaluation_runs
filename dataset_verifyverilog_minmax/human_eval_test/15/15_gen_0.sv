module number_sequence (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  output reg [7:0] char_out,
  output reg valid,
  output reg done
);
  
  typedef enum logic [1:0] { IDLE = 2'b00, OUTPUT_NUM = 2'b01, OUTPUT_SPACE = 2'b10 } state_t;
  state_t st, st_nxt;
  
  // Internal control/state registers
  reg [3:0] n_reg, n_next;
  reg [3:0] num_cur, num_next;      // Current number being output (0..n)
  reg [3:0] idx, idx_next;          // Digit index for current number (0 or 1)
  reg [7:0] next_char;
  reg [3:0] digit_len;
  reg at_last_number;
  reg output_space_next;
  
  // Next-space logic: space is output only before numbers > 0, and only if there is a next number
  wire [3:0] next_number = (num_cur < n_reg) ? (num_cur + 1) : 4'd0;
  always_comb begin
    if (st == IDLE) begin
      st_nxt = (start ? OUTPUT_NUM : IDLE);
      done = 1'b0;
    end else if (st == OUTPUT_NUM) begin
      // On the last character of the last number, we finish in the same cycle
      if (at_last_number && (idx == (digit_len - 1))) begin
        st_nxt = IDLE;
        done = 1'b1;
      end else begin
        st_nxt = OUTPUT_NUM;
        done = 1'b0;
      end
    end else begin // OUTPUT_SPACE
      st_nxt = OUTPUT_NUM;
      done = 1'b0;
    end
  end
  
  // Combinational: compute next char, digit length, and next pointers
  function [7:0] to_ascii(input [3:0] val);
    // val is 0..15; we only call this for 0..9 in this design
    return 8'(48 + val);
  endfunction
  
  always_comb begin
    // Defaults to avoid latches
    n_next     = n_reg;
    num_next   = num_cur;
    idx_next   = idx;
    next_char  = 8'h00;
    digit_len  = (num_cur < 4'd10) ? 4'd1 : 4'd2;
    at_last_number = (num_cur == n_reg);
    output_space_next = 1'b0;
    
    case (st)
      IDLE: begin
        // char_out not driven in IDLE per spec (driven by next state logic below)
        idx_next = 4'd0;
      end
      OUTPUT_NUM: begin
        next_char = to_ascii(num_cur[3:0]);
        if (at_last_number && (idx == (digit_len - 1))) begin
          // Last output character: hold counters; state machine will go to IDLE
          n_next     = n_reg;
          num_next   = num_cur;
          idx_next   = idx;
        end else begin
          // Not last character: advance within current number
          idx_next = idx + 1;
          if (idx == (digit_len - 1)) begin
            // Finished current number
            if (num_cur < n_reg) begin
              // More numbers remain: output a space next, then move to next number
              output_space_next = 1'b1;
              num_next = num_cur + 1;
              idx_next = 4'd0;
            end else begin
              // This was the last number (safety fallback, normally caught above)
              num_next = num_cur;
            end
          end else begin
            // Continue within same number
            num_next = num_cur;
          end
        end
      end
      OUTPUT_SPACE: begin
        next_char = 8'd32; // space
        // Stay in SPACE for exactly 1 cycle, then back to OUTPUT_NUM
        n_next     = n_reg;
        num_next   = num_cur;
        idx_next   = idx;
      end
      default: begin
        n_next     = n_reg;
        num_next   = num_cur;
        idx_next   = idx;
      end
    endcase
  end
  
  // State and output registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      st       <= IDLE;
      n_reg    <= 4'd0;
      num_cur  <= 4'd0;
      idx      <= 4'd0;
    end else begin
      st       <= st_nxt;
      n_reg    <= n_next;
      num_cur  <= num_next;
      idx      <= idx_next;
    end
  end
  
  // Output muxes for char_out and valid
  always_comb begin
    char_out = 8'd0;
    valid    = 1'd0;
    case (st)
      IDLE: begin
        char_out = 8'd0;
        valid    = 1'd0;
      end
      OUTPUT_NUM: begin
        char_out = next_char;
        valid    = 1'd1;
      end
      OUTPUT_SPACE: begin
        char_out = 8'd32; // space
        valid    = 1'd1;
      end
      default: begin
        char_out = 8'd0;
        valid    = 1'd0;
      end
    endcase
  end
  
  // Register the n input when starting a new sequence
  always_ff @(posedge clk) begin
    if (st == IDLE && start) begin
      n_reg <= n;
    end
  end
  
endmodule