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

  typedef enum logic [1:0] { IDLE, COMPUTE, DONE } state_t;
  state_t state, next_state;

  reg [3:0] i_cnt, j_cnt, k_cnt;
  reg [7:0] L [0:8][0:8][0:8];

  function logic [7:0] max3(input logic [7:0] a, b, c);
    logic [7:0] tmp;
    tmp = (a > b) ? a : b;
    max3 = (tmp > c) ? tmp : c;
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      lcs_length <= 8'b0;
      done <= 1'b0;
      i_cnt <= 4'd1;
      j_cnt <= 4'd1;
      k_cnt <= 4'd1;
      for (int i=0; i<=8; i++)
        for (int j=0; j<=8; j++)
          for (int k=0; k<=8; k++)
            L[i][j][k] <= 8'b0;
    end else begin
      state <= next_state;
      done <= (state == DONE);

      case (state)
        IDLE: begin
          i_cnt <= 4'd1;
          j_cnt <= 4'd1;
          k_cnt <= 4'd1;
        end

        COMPUTE: begin
          if (str1[i_cnt-1] == str2[j_cnt-1] && str1[i_cnt-1] == str3[k_cnt-1]) begin
            L[i_cnt][j_cnt][k_cnt] <= L[i_cnt-1][j_cnt-1][k_cnt-1] + 1'b1;
          end else begin
            L[i_cnt][j_cnt][k_cnt] <= max3(L[i_cnt-1][j_cnt][k_cnt],
                                          L[i_cnt][j_cnt-1][k_cnt],
                                          L[i_cnt][j_cnt][k_cnt-1]);
          end

          if (k_cnt < 8) begin
            k_cnt <= k_cnt + 1'b1;
          end else begin
            k_cnt <= 4'd1;
            if (j_cnt < 8) begin
              j_cnt <= j_cnt + 1'b1;
            end else begin
              j_cnt <= 4'd1;
              if (i_cnt < 8) begin
                i_cnt <= i_cnt + 1'b1;
              end
            end
          end
        end

        DONE: begin
          lcs_length <= L[8][8][8];
        end
      endcase
    end
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE: if (start) next_state = COMPUTE;
      COMPUTE: if (i_cnt==8 && j_cnt==8 && k_cnt==8) next_state = DONE;
      DONE: if (start) next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

endmodule