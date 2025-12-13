module lps_calculator(
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0] str [0:7],
  output reg [3:0] lps_length,
  output reg done
);

  // State encoding
  localparam IDLE         = 2'b00;
  localparam INIT_MATRIX  = 2'b01;
  localparam PROCESS_SUB  = 2'b10;
  localparam COMPLETE     = 2'b11;

  reg [1:0] state, next_state;

  // DP matrix L: 8x8, 4 bits per entry
  reg [3:0] L [0:7][0:7];

  // Indices and length control
  reg [3:0] len;   // current substring length (1..8)
  reg [2:0] i;     // start index
  reg [2:0] j;     // end index = i + len - 1

  // Control for INIT and PROCESS loops
  reg [2:0] init_idx; // for diagonal initialization

  // Wires for comparisons and DP values
  wire [2:0] j_calc = i + len - 1;
  wire       in_range = (j_calc < 8);

  // Max helper
  function [3:0] max4;
    input [3:0] a;
    input [3:0] b;
    begin
      max4 = (a >= b) ? a : b;
    end
  endfunction

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = INIT_MATRIX;
      end

      INIT_MATRIX: begin
        if (init_idx == 3'd7)
          next_state = PROCESS_SUB;
      end

      PROCESS_SUB: begin
        // When len has reached 8 and we've completed all i for that len
        // we move to COMPLETE. Completion condition handled in seq logic.
        if ((len == 4'd8) && (!in_range))
          next_state = COMPLETE;
      end

      COMPLETE: begin
        // Stay in COMPLETE until a new start or reset; here we choose to
        // go back to IDLE when start is deasserted then asserted again.
        if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  integer x, y;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      done        <= 1'b0;
      lps_length  <= 4'd0;
      len         <= 4'd0;
      i           <= 3'd0;
      init_idx    <= 3'd0;
      // Clear matrix
      for (x = 0; x < 8; x = x + 1) begin
        for (y = 0; y < 8; y = y + 1) begin
          L[x][y] <= 4'd0;
        end
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done       <= 1'b0;
          lps_length <= 4'd0;
          if (start) begin
            // Prepare for initialization
            init_idx <= 3'd0;
            len      <= 4'd0;
            i        <= 3'd0;
          end
        end

        INIT_MATRIX: begin
          // Set diagonal L[i][i] = 1 for all i
          L[init_idx][init_idx] <= 4'd1;
          if (init_idx < 3'd7) begin
            init_idx <= init_idx + 3'd1;
          end else begin
            // Move to processing lengths starting from 2
            len <= 4'd2;
            i   <= 3'd0;
          end
        end

        PROCESS_SUB: begin
          if (len <= 4'd8) begin
            if (in_range) begin
              // Valid (i,j) for this len
              j <= j_calc;
              if (len == 4'd1) begin
                // Already handled in INIT; no-op
                L[i][j_calc] <= 4'd1;
              end else if (len == 4'd2) begin
                if (str[i] == str[j_calc])
                  L[i][j_calc] <= 4'd2;
                else
                  L[i][j_calc] <= 4'd1;
              end else begin
                if (str[i] == str[j_calc]) begin
                  L[i][j_calc] <= L[i+1][j_calc-1] + 4'd2;
                end else begin
                  L[i][j_calc] <= max4(L[i+1][j_calc], L[i][j_calc-1]);
                end
              end

              // Advance i for next cycle
              i <= i + 3'd1;
            end else begin
              // Completed all i for this len; move to next len
              i <= 3'd0;
              if (len < 4'd8)
                len <= len + 4'd1;
            end
          end
        end

        COMPLETE: begin
          // Final result at L[0][7]
          lps_length <= L[0][7];
          done       <= 1'b1;
        end
      endcase
    end
  end

endmodule