module text_encoder (
  input clk,
  input rst_n,
  input start,
  input wire [7:0] data_in [15:0],
  output reg [7:0] data_out [15:0],
  output reg done
);

  // Internal pipeline for processing
  reg [15:0] pipe_we;
  reg [7:0] pipe_char [15:0];
  integer i;

  // 4-bit counters for timing
  reg [3:0] cnt_in, cnt_out;

  // Function: Swap ASCII case (A<->a, Z<->z). Non-letters unchanged.
  function [7:0] ascii_case_swap;
    input [7:0] ch;
    begin
      if (ch >= "A" && ch <= "Z") ascii_case_swap = ch + 8'd32;   // to lowercase
      else if (ch >= "a" && ch <= "z") ascii_case_swap = ch - 8'd32; // to uppercase
      else ascii_case_swap = ch;
    end
  endfunction

  // Function: Replace vowel with char two positions forward (AEIOUaeiou -> +2)
  // Falls back to input char for non-vowels.
  function [7:0] vowel_map;
    input [7:0] ch;
    case (ch)
      "A","E","I","O","U","a","e","i","o","u": vowel_map = ch + 8'd2;
      default: vowel_map = ch;
    endcase
  endfunction

  // Process each character independently: case swap, then vowel map if vowel
  function [7:0] process_char;
    input [7:0] ch;
    reg [7:0] swapped;
    begin
      swapped = ascii_case_swap(ch);
      process_char = vowel_map(swapped);
    end
  endfunction

  // Sequential control: 1 cycle per character + last cycle for done
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pipe_we <= 16'b0;
      cnt_in <= 4'd0;
      cnt_out <= 4'd0;
      for (i = 0; i < 16; i = i + 1) pipe_char[i] <= 8'd0;
      done <= 1'b0;
    end else begin
      // Shift enable and data through pipeline
      pipe_we <= {pipe_we[14:0], start};
      cnt_in <= (start ? (cnt_in + 1) : cnt_in);
      for (i = 0; i < 16; i = i + 1) begin
        if (i == 0) pipe_char[0] <= (start ? process_char(data_in[0]) : pipe_char[0]);
        else pipe_char[i] <= pipe_we[i-1] ? process_char(data_in[i]) : pipe_char[i];
      end

      // Track the position that will complete this batch (16th character)
      if (start) begin
        if (cnt_in == 4'd15) cnt_out <= 4'd0; else cnt_out <= cnt_out + 1;
      end

      // done is high only when the 16th write occurs
      done <= start && (cnt_in == 4'd15);
    end
  end

  // Write results to output as pipeline completes
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < 16; i = i + 1) data_out[i] <= 8'd0;
    end else begin
      for (i = 0; i < 16; i = i + 1) begin
        data_out[i] <= pipe_we[i] ? pipe_char[i] : data_out[i];
      end
    end
  end

endmodule