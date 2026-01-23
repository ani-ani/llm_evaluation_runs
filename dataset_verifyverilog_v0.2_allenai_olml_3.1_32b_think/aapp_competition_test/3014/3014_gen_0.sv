module disco_cyber_security (input clk,input rst_n,input start,input [3:0] num_nodes,input [4:0] num_edges,input [3:0] edge_u [0:15],input [3:0] edge_v [0:15],output reg [3:0] num_remove,output reg [3:0] remove_indices [0:7],output reg done);
reg [3:0] num_nodes_reg;
reg [4:0] num_edges_reg;
reg [3:0] edge_u_reg [0:15];
reg [3:0] edge_v_reg [0:15];
reg [2:0] state;
reg [3:0] remove_count;
reg [3:0] remove_indices_reg [0:7];
reg [4:0] max_remove;
reg [3:0] i;
always_ff @(posedge clk) begin
   if (!rst_n) begin
      num_nodes_reg <= 4'd0;
      num_edges_reg <= 5'd0;
      state <= 3'b000;
      remove_count <= 4'd0;
      max_remove <= 4'd0;
      i <= 4'd0;
      done <= 1'b0;
      remove_indices_reg <= 4'd0;
      edge_u_reg <= 4'd0;
      edge_v_reg <= 4'd0;
   end else begin
      if (start) begin
         if (state == 3'b000) begin // IDLE: move to READ
            state <= 3'b001;
         end
      end
      // In READ state, capture inputs
      if (state == 3'b001) begin
         num_nodes_reg <= num_nodes;
         num_edges_reg <= num_edges;
         edge_u_reg <= edge_u;
         edge_v_reg <= edge_v;
         max_remove <= (num_edges_reg >> 1);
         if (num_edges_reg == 0) begin
            state <= 3'b010;
         end else begin
            state <= 3'b010;
         end
      end
      // In PROCESS state: prepare for processing
      if (state == 3'b010) begin
         remove_count <= 4'd0;
         i <= 4'd0;
         state <= 3'b011;
      end
      // In PROCESSING state
      if (state == 3'b011) begin
         if (i < num_edges_reg) begin
            if (edge_u_reg[i] == edge_v_reg[i] && remove_count < max_remove) begin
               remove_indices_reg[remove_count] <= i+1;
               remove_count <= remove_count + 1;
            end
            i <= i + 1;
         end else begin
            state <= 3'b100;
         end
      end
   end
end
// Combinational logic for outputs
always_comb begin
   done = (state == 3'b100);
   if (done) begin
      num_remove <= remove_count;
      remove_indices = remove_indices_reg;
   end else begin
      num_remove <= 4'd0;
      remove_indices = 4'd0;
   end
end
endmodule