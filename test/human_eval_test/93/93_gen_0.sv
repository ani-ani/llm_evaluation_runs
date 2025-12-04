module text_encoder(
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0] data_in [15:0],
  output reg [7:0] data_out [15:0],
  output reg done
);

  reg [4:0] idx; // index 0..16
  reg busy;

  // Function to check if character is alphabetic
  function automatic is_alpha;
    input [7:0] c;
    begin
      is_alpha = ((c >= "A") && (c <= "Z")) || ((c >= "a") && (c <= "z"));
    end
  endfunction

  // Function to check if character is vowel (any case)
  function automatic is_vowel;
    input [7:0] c;
    begin
      case (c)
        "A","E","I","O","U",
        "a","e","i","o","u": is_vowel = 1'b1;
        default: is_vowel = 1'b0;
      endcase
    end
  endfunction

  // Function: swap case if letter, otherwise pass through
  function automatic [7:0] swap_case;
    input [7:0] c;
    begin
      if ((c >= "A") && (c <= "Z"))
        swap_case = c + 8'd32; // to lowercase
      else if ((c >= "a") && (c <= "z"))
        swap_case = c - 8'd32; // to uppercase
      else
        swap_case = c; // non-letter unchanged
    end
  endfunction

  // Function: encode character per spec
  function automatic [7:0] encode_char;
    input [7:0] c_in;
    reg [7:0] c_swapped;
    begin
      // Non-letter: unchanged
      if (!is_alpha(c_in)) begin
        encode_char = c_in;
      end else begin
        // Swap case first
        c_swapped = swap_case(c_in);
        // If original is vowel, advance two positions from swapped
        if (is_vowel(c_in))
          encode_char = c_swapped + 8'd2;
        else
          encode_char = c_swapped;
      end
    end
  endfunction

  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous active-low reset
      for (i = 0; i < 16; i = i + 1) begin
        data_out[i] <= 8'd0;
      end
      idx  <= 5'd0;
      busy <= 1'b0;
      done <= 1'b0;
    end else begin
      if (!busy) begin
        done <= 1'b0;
        if (start) begin
          // Start processing
          busy <= 1'b1;
          idx  <= 5'd0;
        end
      end else begin
        // Busy: process one character per cycle
        if (idx < 5'd16) begin
          data_out[idx] <= encode_char(data_in[idx]);
          idx <= idx + 5'd1;
          done <= 1'b0;
        end else begin
          // 17th cycle: assert done, then go idle
          done <= 1'b1;
          busy <= 1'b0;
        end
      end
    end
  end

endmodule