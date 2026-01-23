module min_error_calculator (
   input clk,
   input rst_n,
   input start,
   input [5:0] k_total,
   input [2:0] n,
   input signed [15:0] a [0:7],
   input signed [15:0] b [0:7],
   output reg [31:0] result,
   output reg done
);

   parameter IDLE = 3'd0, COMPUTE_DIFF =3'd1, FIND_MAX=3'd2, UPDATE=3'd3, CALCULATE_RESULT=3'd4, DONE=3'd5;

   reg [2:0] state, next_state;
   reg [5:0] op_count;
   reg signed [15:0] a_reg [0:7];
   reg signed [15:0] b_reg [0:7];
   reg [15:0] d_reg [0:7];
   reg [15:0] max_val_reg;
   reg [2:0] max_index_reg;
   reg [31:0] result_reg;
   reg done_reg;
   assign result = result_reg;
   assign done = done_reg;

   always @(*) begin
      state <= IDLE;
      next_state <= IDLE;
      op_count <=0;
      done_reg <=0;
      result_reg <=0;
      a_reg <= {16{16'b0}};
      b_reg <= {16{16'b0}};
      d_reg <= {16{16'b0}};
      max_val_reg <=0;
      max_index_reg <=0;
   end

   always @(posedge clk) begin
      if (!rst_n) begin
         state <= IDLE;
         next_state <= IDLE;
         op_count <=0;
         done_reg <=0;
         result_reg <=0;
         a_reg <= {16{16'b0}};
         b_reg <= {16{16'b0}};
         d_reg <= {16{16'b0}};
         max_val_reg <=0;
         max_index_reg <=0;
      end else begin
         state <= next_state;
         if (state == COMPUTE_DIFF) begin
            a_reg <= a;
            b_reg <= b;
            if (n > 0) begin
               signed [15:0] diff = a_reg[0] - b_reg[0];
               d_reg[0] = (diff >=0) ? diff : -diff;
            end else d_reg[0] =0;
            if (n > 1) begin
               signed [15:0] diff = a_reg[1] - b_reg[1];
               d_reg[1] = (diff >=0) ? diff : -diff;
            end else d_reg[1] =0;
            if (n > 2) begin
               signed [15:0] diff = a_reg[2] - b_reg[2];
               d_reg[2] = (diff >=0) ? diff : -diff;
            end else d_reg[2] =0;
            if (n > 3) begin
               signed [15:0] diff = a_reg[3] - b_reg[3];
               d_reg[3] = (diff >=0) ? diff : -diff;
            end else d_reg[3] =0;
            if (n > 4) begin
               signed [15:0] diff = a_reg[4] - b_reg[4];
               d_reg[4] = (diff >=0) ? diff : -diff;
            end else d_reg[4] =0;
            if (n > 5) begin
               signed [15:0] diff = a_reg[5] - b_reg[5];
               d_reg[5] = (diff >=0) ? diff : -diff;
            end else d_reg[5] =0;
            if (n > 6) begin
               signed [15:0] diff = a_reg[6] - b_reg[6];
               d_reg[6] = (diff >=0) ? diff : -diff;
            end else d_reg[6] =0;
            if (k_total ==0) next_state <= CALCULATE_RESULT; else begin
               op_count <=0;
               next_state <= FIND_MAX;
            end
         end else if (state == FIND_MAX) begin
            localparam int max_val =0, max_index =0;
            if (n>0) if (d_reg[0] > max_val) begin max_val = d_reg[0]; max_index =0; end
            if (n>1) if (d_reg[1] > max_val) begin max_val = d_reg[1]; max_index =1; end
            if (n>2) if (d_reg[2] > max_val) begin max_val = d_reg[2]; max_index =2; end
            if (n>3) if (d_reg[3] > max_val) begin max_val = d_reg[3]; max_index =3; end
            if (n>4) if (d_reg[4] > max_val) begin max_val = d_reg[4]; max_index =4; end
            if (n>5) if (d_reg[5] > max_val) begin max_val = d_reg[5]; max_index =5; end
            if (n>6) if (d_reg[6] > max_val) begin max_val = d_reg[6]; max_index =6; end
            max_val_reg <= max_val;
            max_index_reg <= max_index;
            if (op_count < k_total) next_state <= UPDATE; else next_state <= CALCULATE_RESULT;
         end else if (state == UPDATE) begin
            if (max_val_reg >0) d_reg[max_index_reg] <= d_reg[max_index_reg] -1; else d_reg[max_index_reg] <=1;
            op_count <= op_count +1;
            if (op_count < k_total) next_state <= FIND_MAX; else next_state <= CALCULATE_RESULT;
         end else if (state == CALCULATE_RESULT) begin
            localparam int sum_sq =0;
            if (n>0) sum_sq += d_reg[0]*d_reg[0];
            if (n>1) sum_sq += d_reg[1]*d_reg[1];
            if (n>2) sum_sq += d_reg[2]*d_reg[2];
            if (n>3) sum_sq += d_reg[3]*d_reg[3];
            if (n>4) sum_sq += d_reg[4]*d_reg[4];
            if (n>5) sum_sq += d_reg[5]*d_reg[5];
            if (n>6) sum_sq += d_reg[6]*d_reg[6];
            result_reg <= sum_sq;
            done_reg <=1;
            next_state <= DONE;
         end else if (state == DONE) begin
            next_state <= DONE;
            done_reg <=1;
         end else if (state == IDLE) begin
            if (start) next_state <= COMPUTE_DIFF; else next_state <= IDLE;
         end
      end
   end
endmodule