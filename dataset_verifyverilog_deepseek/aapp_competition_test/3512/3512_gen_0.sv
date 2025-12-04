module tsp_special(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [63:0][9:0] dist_matrix,
  output reg [12:0] min_duration,
  output reg done
);

  reg [1:0] state;
  localparam IDLE = 2'd0;
  localparam INIT = 2'd1;
  localparam PROCESS = 2'd2;
  localparam DONE = 2'd3;
  
  reg [2:0] cnt_init;
  reg [2:0] s_cnt;
  reg [2:0] l_cnt;
  
  reg [12:0] dp_LL [0:7][0:7];  // end at left
  reg [12:0] dp_RR [0:7][0:7];  // end at right
  
  wire [3:0] R = l_cnt + s_cnt - 3'd1;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      min_duration <= 13'b0;
      cnt_init <= 3'b0;
      s_cnt <= 3'd2;
      l_cnt <= 3'b0;
      for (int i=0; i<8; i=i+1) begin
        for (int j=0; j<8; j=j+1) begin
          dp_LL[i][j] <= 13'd8191;
          dp_RR[i][j] <= 13'd8191;
        end
      end
    end
    else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            state <= INIT;
            cnt_init <= 3'b0;
          end
        end
        
        INIT: begin
          dp_LL[cnt_init][cnt_init] <= 13'd0;
          dp_RR[cnt_init][cnt_init] <= 13'd0;
          if (cnt_init < n-1) cnt_init <= cnt_init + 1;
          else state <= PROCESS;
        end
        
        PROCESS: begin
          if (s_cnt > n) begin
            state <= DONE;
            min_duration <= (dp_LL[0][n-1] < dp_RR[0][n-1]) ? dp_LL[0][n-1] : dp_RR[0][n-1];
          end
          else begin
            if (l_cnt <= n - s_cnt) begin
              // Update left endpoint cost
              dp_LL[l_cnt][R] <= (dp_LL[l_cnt+3'd1][R] + dist_matrix[((l_cnt+3'd1)<<3)+l_cnt] <
                                   dp_RR[l_cnt+3'd1][R] + dist_matrix[(R<<3)+l_cnt]) ?
                                  (dp_LL[l_cnt+3'd1][R] + dist_matrix[((l_cnt+3'd1)<<3)+l_cnt]) :
                                  (dp_RR[l_cnt+3'd1][R] + dist_matrix[(R<<3)+l_cnt]);
              
              // Update right endpoint cost
              dp_RR[l_cnt][R] <= (dp_LL[l_cnt][R-3'd1] + dist_matrix[(l_cnt<<3)+R] <
                                   dp_RR[l_cnt][R-3'd1] + dist_matrix[((R-3'd1)<<3)+R]) ?
                                  (dp_LL[l_cnt][R-3'd1] + dist_matrix[(l_cnt<<3)+R]) :
                                  (dp_RR[l_cnt][R-3'd1] + dist_matrix[((R-3'd1)<<3)+R]);
              
              if (l_cnt == n - s_cnt) begin
                l_cnt <= 0;
                s_cnt <= s_cnt + 1;
              end
              else l_cnt <= l_cnt + 1;
            end
            else begin
              s_cnt <= s_cnt + 1;
              l_cnt <= 0;
            end
          end
        end
        
        DONE: begin
          done <= 1'b1;
          if (start) state <= IDLE;
        end
      endcase
    end
  end
endmodule