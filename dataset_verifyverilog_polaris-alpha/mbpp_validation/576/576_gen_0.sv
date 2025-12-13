module sublist_checker(
  input        clk,
  input        rst_n,
  input        start,
  input [15:0] array_A,
  input [15:0] array_B,
  input [1:0]  ENA,
  input [1:0]  ENB,
  output reg   found,
  output reg   done
);

  // Internal registers
  reg [1:0] lenA, lenB;
  reg [1:0] max_start;        // maximum valid start index in A
  reg [1:0] idx;              // current start index being checked
  reg       started;          // indicates an active operation

  // Element extraction function
  function automatic [3:0] getA;
    input [15:0] a;
    input [1:0]  i;
    begin
      case (i)
        2'd0: getA = a[3:0];
        2'd1: getA = a[7:4];
        2'd2: getA = a[11:8];
        default: getA = a[15:12];
      endcase
    end
  endfunction

  function automatic [3:0] getB;
    input [15:0] b;
    input [1:0]  i;
    begin
      case (i)
        2'd0: getB = b[3:0];
        2'd1: getB = b[7:4];
        2'd2: getB = b[11:8];
        default: getB = b[15:12];
      endcase
    end
  endfunction

  // Combinational parallel match for current idx
  wire m0, m1, m2, m3;

  assign m0 = (lenB >= 2'd1) ? (getA(array_A, idx) == getB(array_B, 2'd0)) : 1'b1;
  assign m1 = (lenB >= 2'd2) ? (getA(array_A, idx + 2'd1) == getB(array_B, 2'd1)) : 1'b1;
  assign m2 = (lenB >= 2'd3) ? (getA(array_A, idx + 2'd2) == getB(array_B, 2'd2)) : 1'b1;
  assign m3 = (lenB == 2'd3) ? (getA(array_A, idx + 2'd3) == getB(array_B, 2'd3)) : 1'b1;

  wire match_cur = m0 & m1 & m2 & m3;

  // Sequential control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      found   <= 1'b0;
      done    <= 1'b0;
      lenA    <= 2'd0;
      lenB    <= 2'd0;
      max_start <= 2'd0;
      idx     <= 2'd0;
      started <= 1'b0;
    end else begin
      // default outputs when not done
      if (!started) begin
        done  <= 1'b0;
        found <= 1'b0;
      end

      if (start && !started) begin
        // Latch lengths
        lenA <= ENA + 2'd1;
        lenB <= ENB + 2'd1;
        started <= 1'b1;
        found   <= 1'b0;
        done    <= 1'b0;
      end else if (started && !done) begin
        // Handle edge and invalid cases on first active cycle
        if (lenB == 0 || lenA == 0 || lenB > lenA) begin
          done <= 1'b1;
        end else begin
          max_start <= lenA - lenB + 2'd1;
          idx <= 2'd0;
        end
      end else if (started && done && start) begin
        // Restart
        lenA <= ENA + 2'd1;
        lenB <= ENB + 2'd1;
        max_start <= lenA - lenB + 2'd1;
        idx <= 2'd0;
        found <= 1'b0;
      end else if (started && !done) begin
        if (idx < max_start) begin
          if (match_cur) begin
            found <= 1'b1;
            done <= 1'b1;
          end else begin
            idx <= idx + 2'd1;
          end
        end else begin
          done <= 1'b1;
        end
      end
    end
  end
endmodule