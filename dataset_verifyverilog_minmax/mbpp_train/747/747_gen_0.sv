module lcs_three_strings (
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] str1,
  input [7:0][7:0] str2,
  input [7:0][7:0] str3,
  output reg [7:0] lcs_length,
  output reg done
);

  // State encoding
  localparam IDLE = 2'b00;
  localparam COMPUTE = 2'b01;
  localparam DONE = 2'b10;

  // DP table: L[9][9][9], each entry 8-bit (LCS length is at most 8)
  reg [7:0] L [0:8][0:8][0:8];

  // Loop indices for i, j, k (0..8)
  reg [3:0] i, j, k;
  reg [3:0] nxt_i, nxt_j, nxt_k;

  // State and control
  reg [1:0] state, next_state;
  reg start_d;
  wire start_rising;

  // Max-of-3 function for 8-bit values
  function [7:0] max3;
    input [7:0] a, b, c;
    begin
      max3 = (a >= b) ? ((a >= c) ? a : c) : ((b >= c) ? b : c);
    end
  endfunction

  // Start pulse detection
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d <= 1'b0;
    end else begin
      start_d <= start;
    end
  end
  assign start_rising = (start && !start_d);

  // Sequential state and index update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 4'd0;
      j <= 4'd0;
      k <= 4'd0;
      nxt_i <= 4'd0;
      nxt_j <= 4'd0;
      nxt_k <= 4'd0;
    end else begin
      state <= next_state;
      i <= nxt_i;
      j <= nxt_j;
      k <= nxt_k;
    end
  end

  // Next-state and combinational index logic
  always @(*) begin
    // Default: hold current indices
    nxt_i = i;
    nxt_j = j;
    nxt_k = k;

    case (state)
      IDLE: begin
        if (start_rising) begin
          nxt_i = 4'd0;
          nxt_j = 4'd0;
          nxt_k = 4'd0;
        end
      end

      COMPUTE: begin
        // Default: keep current indices until update
        nxt_i = i;
        nxt_j = j;
        nxt_k = k;

        // Advance k first, then j, then i (i major loop)
        if (k < 4'd8) begin
          nxt_k = k + 1'b1;
        end else begin
          nxt_k = 4'd0;
          if (j < 4'd8) begin
            nxt_j = j + 1'b1;
          end else begin
            nxt_j = 4'd0;
            if (i < 4'd8) begin
              nxt_i = i + 1'b1;
            end
            // else: will finish next state
          end
        end
      end

      DONE: begin
        // Hold until next start
        nxt_i = i;
        nxt_j = j;
        nxt_k = k;
      end

      default: begin
        nxt_i = i;
        nxt_j = j;
        nxt_k = k;
      end
    endcase
  end

  // DP table update and outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset DP table and outputs
      lcs_length <= 8'd0;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          lcs_length <= 8'd0; // Hold at zero until computation starts
        end

        COMPUTE: begin
          // Update the DP cell L[i][j][k] at this clock edge
          if ((i > 0) && (j > 0) && (k > 0)) begin
            if ((str1[i-1] == str2[j-1]) && (str1[i-1] == str3[k-1])) begin
              L[i][j][k] <= L[i-1][j-1][k-1] + 1'b1;
            end else begin
              L[i][j][k] <= max3(L[i-1][j][k], L[i][j-1][k], L[i][j][k-1]);
            end
          end else begin
            L[i][j][k] <= 8'd0; // Base cases remain zero
          end
        end

        DONE: begin
          // Keep result stable until next start
          lcs_length <= L[8][8][8];
          done <= 1'b1;
        end
      endcase
    end
  end

  // State machine next-state logic
  always @(*) begin
    case (state)
      IDLE:    next_state = start_rising ? COMPUTE : IDLE;
      COMPUTE: begin
        // Completed all cells: i,j,k = 8 and next step would overflow to 9
        if ((i == 4'd8) && (j == 4'd8) && (k == 4'd8)) begin
          next_state = DONE;
        end else begin
          next_state = COMPUTE;
        end
      end
      DONE:    next_state = start_rising ? COMPUTE : DONE;
      default: next_state = IDLE;
    endcase
  end

endmodule