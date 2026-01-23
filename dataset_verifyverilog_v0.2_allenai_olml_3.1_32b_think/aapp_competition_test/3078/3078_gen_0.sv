module longest_interesting_subsequence (
input clk,
input rst_n, // active-low reset
input start,
input [7:0] A [0:15],
input [31:0] S,
output reg [7:0] result [0:15],
output reg done
);

localparam N = 16;

reg [7:0] a_reg [0:N-1];
reg [31:0] s_reg;
reg [7:0] result_reg [0:N-1];
reg [8:0] counter; // 9 bits
reg [1:0] state; // 0:IDLE, 1:COMPUTE, 2:DONE
reg [7:0] current_result [0:N-1];

always @(posedge clk) if (!rst_n) begin
   state <= 0;
   a_reg <= 0;
   s_reg <=0;
   result_reg <=0;
   done <=0;
   counter <=0;
end else begin
   case (state)
      0: // IDLE
         if (start) begin
            state <= 1;
            a_reg <= A;
            s_reg <= S;
            counter <=0;
         end
      1: // COMPUTE
         counter <= counter +1;
         if (counter == 256) begin
            state <= 2;
            result_reg <= current_result;
            done <=1;
         end
      2: // DONE
         // no action
      default: state <=0;
   endcase
end

always @(*) begin
   if (state == 1) begin // Only compute when in COMPUTE state
      integer i, K, max_len, sum1, sum2, j;
      for (i=0; i<N; i=i+1) begin
         max_len = 0;
         integer max_K = (N - i) / 2;
         for (K=1; K<=max_K; K=K+1) begin
            integer end_pos = i + 2*K -1;
            if (end_pos < N) begin
               sum1 = 0;
               for (j=0; j<K; j=j+1) begin
                  sum1 = sum1 + a_reg[i + j];
               end
               sum2=0;
               for (j=0; j<K; j=j+1) begin
                  sum2 = sum2 + a_reg[i + K + j];
               end
               if (sum1 <= s_reg && sum2 <= s_reg) begin
                  if (2*K > max_len) begin
                     max_len = 2*K;
                  end
               end
            end
         end
         current_result[i] = max_len;
      end
   end else begin
      current_result = 0;
   end
end

endmodule