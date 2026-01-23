module graph_planner (
   input clk,
   input rst_n,
   input start_max,
   input start_min,
   input [2:0] s,
   input [3:0] num_vertices,
   input [15:0] edge_valid,
   input [15:0][2:0] edge_from,
   input [15:0][2:0] edge_to,
   input [15:0] edge_type,
   output reg [3:0] reachable_count,
   output reg [7:0] undirected_orientation,
   output reg busy,
   output reg valid
);

   reg [7:0] reachable_nodes;
   reg [7:0] undir_orient;
   reg [2:0] state;
   reg busy, valid;
   reg [7:0] mask;
   reg [7:0] init_node;

   // Default assignments
   always @(*) begin
      mask = 8'b0;
      init_node = 8'b0;
      state = 3'b000;
      busy = 1'b0;
      valid = 1'b0;
   end

   // Compute mask based on num_vertices
   always_comb begin
      case (num_vertices)
         2: mask = 3;
         3: mask = 7;
         4: mask = 15;
         5: mask = 31;
         6: mask = 63;
         7: mask = 127;
         8: mask = 255;
         default: mask = 0;
      endcase
   end

   // Compute initial node
   always_comb begin
      case (s)
         0: init_node = 1;
         1: init_node = 2;
         2: init_node = 4;
         3: init_node = 8;
         4: init_node = 16;
         5: init_node = 32;
         6: init_node = 64;
         7: init_node = 128;
         default: init_node = 0;
      endcase
   end

   always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         reachable_nodes <= 8'b0;
         undir_orient <= 8'b0;
         state <= 3'b000;
         busy <= 1'b0;
         valid <= 1'b0;
      end else begin
         case (state)
            3'b000: // IDLE
               if (start_max) begin
                  if (!busy) begin
                     // Initialize for MAX
                     reachable_nodes <= init_node & mask;
                     undir_orient <= 8'b0;
                     state <= 3'b001;
                     busy <= 1'b1;
                     valid <= 1'b0;
                  end
               end else if (start_min) begin
                  if (!busy) begin
                     reachable_nodes <= init_node & mask;
                     state <= 3'b010;
                     busy <= 1'b1;
                     valid <= 1'b0;
                  end
               end
            3'b001: // COMPUTING_MAX
               // Simplified: assume computation takes 1 cycle
               if (reachable_nodes != 8'b0) begin
                  state <= 3'b100; // DONE
                  valid <= 1'b1;
                  busy <= 1'b0;
                  // Compute reachable_count
                  reachable_count <= (reachable_nodes != 8'b0) ? 4'b0001 : 4'b0000;
               end
            3'b010: // COMPUTING_MIN
               // Similar to MAX but no undir_orient update
               if (reachable_nodes != 8'b0) begin
                  state <= 3'b100;
                  valid <= 1'b1;
                  busy <= 1'b0;
                  reachable_count <= (reachable_nodes != 8'b0) ? 4'b0001 : 4'b0000;
               end
            3'b100: // DONE
               // retain values
               state <= 3'b100;
            default: state <= 3'b000;
         endcase
      end
   end

   // Output assignments
   assign reachable_count = (state == 3'b100) ? reachable_count : 4'b0;
   assign undirected_orientation = (state == 3'b100) ? undir_orient : 8'b0;
   assign busy = busy;
   assign valid = valid;

endmodule