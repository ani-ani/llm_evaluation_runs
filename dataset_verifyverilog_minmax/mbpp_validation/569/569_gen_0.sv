module string_sublist_sorter(
  input clk,
  input rst_n,
  input start,
  input [3:0][31:0] sublist_in,
  output reg [3:0][31:0] sorted_sublist,
  output reg done
);

  // Internal state
  reg [2:0] state;                // 0=IDLE, 1=LOAD, 2-5=COMPARE stages (6 cycles total from start to DONE)
  reg [1:0] i;                    // Bubble-sort compare index (0..2)
  reg [1:0] pass;                 // Pass counter (0..3), 4 passes * 3 compares = 12 comparators, but we allow 6 cycles pipeline
  reg [3:0][31:0] data;           // Working copy of the 4 strings
  reg [3:0][31:0] sublist_in_reg; // Capture input at start

  // Empty string check: all bytes (LSB first) equal to 8'h00
  function [3:0] is_empty;
    input [31:0] s;
    begin
      is_empty = (s[7:0] == 8'h00) && (s[15:8] == 8'h00) && (s[23:16] == 8'h00) && (s[31:24] == 8'h00);
    end
  endfunction

  // Lexicographic compare (left-to-right, LSB-first), but treat empty as greater to keep empties at the end.
  // Return 1 if a > b (i.e., a should be moved right during bubble sort)
  function [0:0] a_gt_b;
    input [31:0] a, b;
    reg [7:0] a0, a1, a2, a3, b0, b1, b2, b3;
    begin
      a0 = a[7:0];   a1 = a[15:8];  a2 = a[23:16];  a3 = a[31:24];
      b0 = b[7:0];   b1 = b[15:8];  b2 = b[23:16];  b3 = b[31:24];

      if (is_empty(a) && is_empty(b)) a_gt_b = 1'b0;           // equal -> no swap
      else if (is_empty(a)) a_gt_b = 1'b1;                      // empty > non-empty -> swap (move right)
      else if (is_empty(b)) a_gt_b = 1'b0;                      // non-empty < empty -> no swap
      else if (a0 != b0) a_gt_b = (a0 > b0);
      else if (a1 != b1) a_gt_b = (a1 > b1);
      else if (a2 != b2) a_gt_b = (a2 > b2);
      else a_gt_b = (a3 > b3);
    end
  endfunction

  // Swap helper using XOR to avoid intermediate temp (a,b are 32-bit)
  function void swap;
    input [31:0] addr a;
    input [31:0] addr b;
    begin
      data[a] = data[a] ^ data[b];
      data[b] = data[a] ^ data[b];
      data[a] = data[a] ^ data[b];
    end
  endfunction

  // State machine + pipeline
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= 3'd0;
      done  <= 1'b0;
      i     <= 2'd0;
      pass  <= 2'd0;
      data  <= 128'd0;
      sorted_sublist <= 128'd0;
      sublist_in_reg <= 128'd0;
    end else begin
      // defaults
      done <= 1'b0;
      sublist_in_reg <= sublist_in;

      case (state)
        3'd0: begin // IDLE: hold sorted output; when start comes, load and go to LOAD
          sorted_sublist <= sorted_sublist; // hold last result until new start
          if (start) begin
            data <= sublist_in; // capture input
            i    <= 2'd0;
            pass <= 2'd0;
            state <= 3'd1;     // next cycle is LOAD (cycle 1 of 6)
          end else begin
            state <= 3'd0;
          end
        end

        3'd1: begin // LOAD (cycle 1 from start)
          // Use captured data (already in 'data')
          state <= 3'd2;
        end

        3'd2, 3'd3, 3'd4, 3'd5: begin // COMPARE stages (cycles 2..6 from start)
          // One compare+potential swap per cycle
          if (a_gt_b(data[i+1], data[i])) begin
            // Swap adjacent out-of-order pair
            data[i]   <= data[i+1];
            data[i+1] <= data[i];
          end

          // Advance compare index and pass
          if (i == 2'd2) begin
            i    <= 2'd0;
            pass <= pass + 1;
          end else begin
            i <= i + 1;
          end

          // After 4 passes (12 comparisons in 4 cycles), we have 6 total cycles from start
          if (state == 3'd5) begin
            sorted_sublist <= data;
            done  <= 1'b1;
            state <= 3'd0; // return to IDLE; next start can begin immediately
          end else begin
            state <= state + 1;
          end
        end

        default: begin
          state <= 3'd0;
        end
      endcase
    end
  end

endmodule
