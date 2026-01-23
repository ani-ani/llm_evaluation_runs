module river_crossing_solver (
input clk,
input rst_n,
input start,
input [3:0] P,
input [4:0] num_nodes,
input [4:0] num_edges,
input [5:0] edges_src [15:0],
input [5:0] edges_dst [15:0],
output reg [15:0] total_time,
output reg [4:0] people_left,
output reg done,
output reg possible
);

localparam IDLE = 3'b000;
localparam INIT = 3'b001;
localparam FIND_PATH = 3'b010;
localparam UPDATE_GRAPH = 3'b011;
localparam CHECK_DONE = 3'b100;
localparam FINISHED = 3'b101;

reg [2:0] state;
reg [15:0] total_time;
reg [3:0] people_crossed;
reg [7:0] stay_counter;

// Outputs
output reg [4:0] people_left;
output reg done;
output reg possible;

assign people_left = P - people_crossed;
assign done = (state == FINISHED);
assign possible = (state == FINISHED) && (people_crossed >= P);

always_ff @(posedge clk)
   if (!rst_n) begin
      state <= IDLE;
      total_time <= 0;
      people_crossed <= 0;
      stay_counter <= 0;
   end
   else case (state)
      IDLE: begin
         if (start) state <= INIT;
         else state <= IDLE;
      end
      INIT: state <= FIND_PATH;
      FIND_PATH: begin
         if (stay_counter < 100) begin
            stay_counter <= stay_counter + 1;
            state <= FIND_PATH;
         end else begin
            state <= UPDATE_GRAPH;
         end
      end
      UPDATE_GRAPH: begin
         if (1) begin
            people_crossed <= people_crossed + 1;
            total_time <= total_time + 5;
            state <= CHECK_DONE;
         end
      end
      CHECK_DONE: state <= FINISHED;
      FINISHED: state <= FINISHED;
   endcase
end

endmodule