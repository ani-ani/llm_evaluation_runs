module seq_match_finder (
   input clk,
   input rst_n, // active low reset
   input start,
   input reg [3:0] n,
   input reg [3:0] m,
   input reg [3:0] p,
   input reg [3:0] a [0:15],
   input reg [3:0] b [0:15],
   output reg [3:0] result_count,
   output reg [3:0] result_positions [0:15],
   output reg done
);

reg [3:0] b_hist [0:15];
reg [3:0] current_q;
reg [3:0] max_q_reg;
reg [3:0] result_pos_idx;
reg [3:0] result_count;
reg done_flag;
reg [1:0] state_reg;
reg [3:0] b_hist_counter;

localparam IDLE = 2'b00;
localparam INIT_HIST = 2'b01;
localparam COMPARE = 2'b10;
localparam UPDATE_WINDOW = 2'b11;

always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      state_reg <= IDLE;
      b_hist <= {16{4'b0}};
      current_q <= 4'd0;
      max_q_reg <= 4'd0;
      result_pos_idx <= 4'd0;
      result_count <= 4'd0;
      done_flag <= 1'b0;
      b_hist_counter <= 4'd0;
   end else begin
      case (state_reg)
         IDLE: begin
            if (start) begin
               state_reg <= INIT_HIST;
            end
         end
         INIT_HIST: begin
            if (b_hist_counter < m) begin
               b_hist[b[b_hist_counter]] <= b_hist[b[b_hist_counter]] + 1;
               b_hist_counter <= b_hist_counter + 1;
            end else begin
               max_q_reg <= n - 1 - (m-1)*p;
               if (max_q_reg < 4'd0) begin
                  state_reg <= COMPARE;
               end else begin
                  state_reg <= COMPARE;
               end
               b_hist_counter <= 4'd0;
            end
         end
         COMPARE: begin
            reg [3:0] window_hist [0:15] = {16{4'b0}};
            int i;
            for (i=0; i<m; i=i+1) begin
               int addr = current_q + i*p;
               if (addr < n) begin
                  window_hist[a[addr]] <= window_hist[a[addr]] + 1;
               end
            end
            int match = 1;
            for (int j=0; j<16; j=j+1) begin
               if (window_hist[j] != b_hist[j]) begin
                  match <= 1'b0;
                  break;
               end
            end
            if (match == 1'b1) begin
               if (result_pos_idx < 16) begin
                  result_positions[result_pos_idx] <= current_q + 1;
                  result_count <= result_count + 1;
                  result_pos_idx <= result_pos_idx + 1;
               end
            end
            state_reg <= UPDATE_WINDOW;
         end
         UPDATE_WINDOW: begin
            current_q <= current_q + 1;
            if (current_q > max_q_reg) begin
               done_flag <= 1'b1;
            end else begin
               state_reg <= COMPARE;
            end
         end
      endcase
   end
end
