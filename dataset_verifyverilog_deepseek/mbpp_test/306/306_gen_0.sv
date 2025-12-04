module max_inc_subseq(input clk, input rst_n, input start, input [7:0] data [0:7], input [2:0] index, input [2:0] k, output reg [10:0] max_sum, output reg done);
  reg [10:0] dp [0:7][0:7];
  reg [2:0] i, j;
  reg [2:0] state;
  reg [3:0] finish_cnt;
  localparam IDLE = 3'b000;
  localparam INIT = 3'b001;
  localparam COMPUTE_I = 3'b010;
  localparam COMPUTE_J = 3'b011;
  localparam FINISH = 3'b100;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      max_sum <= 0;
      finish_cnt <= 0;
      i <= 0;
      j <= 0;
      for (int a=0; a<8; a=a+1) begin
        for (int b=0; b<8; b=b+1) begin
          dp[a][b] <= 0;
        end
      end
    end
    else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= INIT;
            i <= 0;
            j <= 0;
          end
        end

        INIT: begin
          if (j < 8) begin
            if (i == 0) begin
              if (data[j] > data[0]) dp[0][j] <= {3'b000, data[0]} + {3'b000, data[j]};
              else dp[0][j] <= {3'b000, data[j]};
            end
            j <= j + 1;
          end
          else begin
            i <= 1;
            j <= 0;
            state <= COMPUTE_I;
          end
        end

        COMPUTE_I: begin
          j <= 0;
          state <= COMPUTE_J;
        end

        COMPUTE_J: begin
          if (j < 8) begin
            if ((j > i) && (data[j] > data[i])) begin
              if (dp[i-1][i] + {3'b000, data[j]} > dp[i-1][j]) dp[i][j] <= dp[i-1][i] + data[j];
              else dp[i][j] <= dp[i-1][j];
            end
            else dp[i][j] <= dp[i-1][j];
            j <= j + 1;
          end
          else begin
            if (i < 7) begin
              i <= i + 1;
              state <= COMPUTE_I;
            end
            else begin
              state <= FINISH;
              finish_cnt <= 0;
            end
          end
        end

        FINISH: begin
          if (finish_cnt < 5) finish_cnt <= finish_cnt + 1;
          else begin
            done <= 1;
            state <= IDLE;
          end
          max_sum <= dp[index][k];
        end

        default: state <= IDLE;
      endcase
    end
  end
endmodule