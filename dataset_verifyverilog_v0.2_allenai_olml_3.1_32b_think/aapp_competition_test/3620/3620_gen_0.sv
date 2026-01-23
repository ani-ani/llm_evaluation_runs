module k_coloring_counter (
   input clk,
   input rst_n, // active-low
   input start,
   input [5:0] num_edges,
   input [2:0] edge_u [0:5],
   input [2:0] edge_v [0:5],
   input [31:0] P,
   output reg [31:0] result,
   output reg done,
   output reg valid
);

parameter MAX_ITER = 4096;

reg [31:0] result_reg;
reg [31:0] P_reg;
reg [5:0] num_edges_reg;
reg [2:0] edge_u_reg [0:5];
reg [2:0] edge_v_reg [0:5];
reg [11:0] iteration_counter;
reg [2:0] state;
reg done_reg;

wire valid_coloring;

localparam IDLE = 3'd0;
localparam INIT = 3'd1;
localparam PROCESS = 3'd2;
localparam DONE = 3'd3;

always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      result_reg <= 32'd0;
      P_reg <= 32'd0;
      num_edges_reg <= 6'd0;
      edge_u_reg <= 3'd0;
      edge_v_reg <= 3'd0;
      iteration_counter <= 12'd0;
      state <= IDLE;
      done_reg <= 1'b0;
   end else begin
      state <= next_state;

      case (state)
         INIT: begin
            P_reg <= P;
            num_edges_reg <= num_edges;
            edge_u_reg <= edge_u;
            edge_v_reg <= edge_v;
            iteration_counter <= 12'd0;
            result_reg <= 32'd0;
            done_reg <= 1'b0;
         end
      endcase

      next_state = state;

      case (state)
         IDLE: begin
            if (start == 1'b1) begin
               next_state = INIT;
            end
         end
         INIT: begin
            next_state = PROCESS;
         end
         PROCESS: begin
            if (valid_coloring == 1) begin
               result_reg <= result_reg + 1;
               if (result_reg >= P_reg) result_reg <= result_reg - P_reg;
            end
            iteration_counter <= iteration_counter + 1;
            if (iteration_counter == MAX_ITER) begin
               done_reg <= 1'b1;
               next_state = DONE;
            end else begin
               done_reg <= 1'b0;
            end
         end
         DONE: begin
         end
      endcase
   end
end

always @(*) begin
   valid_coloring = 1;
   if (num_edges_reg > 0) begin
      int u0 = edge_u_reg[0];
      int v0 = edge_v_reg[0];
      int color_u0 = (iteration_counter >> (u0*2)) & 3;
      int color_v0 = (iteration_counter >> (v0*2)) & 3;
      if (color_u0 == color_v0) valid_coloring = 0;
   end
   if (num_edges_reg > 1) begin
      int u1 = edge_u_reg[1];
      int v1 = edge_v_reg[1];
      int color_u1 = (iteration_counter >> (u1*2)) & 3;
      int color_v1 = (iteration_counter >> (v1*2)) & 3;
      if (color_u1 == color_v1) valid_coloring = 0;
   end
   if (num_edges_reg > 2) begin
      int u2 = edge_u_reg[2];
      int v2 = edge_v_reg[2];
      int color_u2 = (iteration_counter >> (u2*2)) & 3;
      int color_v2 = (iteration_counter >> (v2*2)) & 3;
      if (color_u2 == color_v2) valid_coloring = 0;
   end
   if (num_edges_reg > 3) begin
      int u3 = edge_u_reg[3];
      int v3 = edge_v_reg[3];
      int color_u3 = (iteration_counter >> (u3*2)) & 3;
      int color_v3 = (iteration_counter >> (v3*2)) & 3;
      if (color_u3 == color_v3) valid_coloring = 0;
   end
   if (num_edges_reg > 4) begin
      int u4 = edge_u_reg[4];
      int v4 = edge_v_reg[4];
      int color_u4 = (iteration_counter >> (u4*2)) & 3;
      int color_v4 = (iteration_counter >> (v4*2)) & 3;
      if (color_u4 == color_v4) valid_coloring = 0;
   end
   if (num_edges_reg > 5) begin
      int u5 = edge_u_reg[5];
      int v5 = edge_v_reg[5];
      int color_u5 = (iteration_counter >> (u5*2)) & 3;
      int color_v5 = (iteration_counter >> (v5*2)) & 3;
      if (color_u5 == color_v5) valid_coloring = 0;
   end
end

assign result = result_reg;
assign done = done_reg;
assign valid = done_reg;

endmodule