module lps_calculator(
  input clk,
  input rst_n,
  input start,
  input [7:0] str [0:7],
  output reg [3:0] lps_length,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE,
    INIT_MATRIX,
    PROCESS,
    COMPLETE
  } state_t;

  reg [1:0] state;
  reg [3:0] len_reg;
  reg [3:0] L [0:7][0:7];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      lps_length <= 4'd0;
      len_reg <= 4'd0;
      for (int i = 0; i < 8; i++) begin
        for (int j = 0; j < 8; j++) begin
          L[i][j] <= 4'd0;
        end
      end
    end else begin
      case(state)
        IDLE: begin
          done <= 1'b0;
          lps_length <= 4'd0;
          if (start) begin
            state <= INIT_MATRIX;
          end
        end
        INIT_MATRIX: begin
          for (int i = 0; i < 8; i++) begin
            L[i][i] <= 4'd1;
          end
          state <= PROCESS;
          len_reg <= 4'd2;
        end
        PROCESS: begin
          for (int idx = 0; idx <= (8 - len_reg); idx++) begin
            int i = idx;
            int j = i + len_reg - 1;
            if (str[i] == str[j]) begin
              L[i][j] <= L[i+1][j-1] + 4'd2;
            end else begin
              automatic int left = L[i][j-1];
              automatic int right = L[i+1][j];
              L[i][j] <= (left > right) ? left : right;
            end
          end
          if (len_reg == 4'd8) begin
            state <= COMPLETE;
          end else begin
            len_reg <= len_reg + 1;
          end
        end
        COMPLETE: begin
          done <= 1'b1;
          lps_length <= L[0][7];
          if (start) begin
            state <= INIT_MATRIX;
            done <= 1'b0;
            lps_length <= 4'd0;
          end
        end
      endcase
    end
  end

endmodule