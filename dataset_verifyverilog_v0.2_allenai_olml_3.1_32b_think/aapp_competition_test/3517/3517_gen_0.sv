module airplane_construction (
input clk,
input rst_n, // active-low reset
input start,
input [2:0] step_count,
input [7:0] step_times [0:7],
output reg [15:0] min_time,
output reg done
)
reg [2:0] step_count_reg;
reg [7:0] step_times_reg [0:7];
reg [7:0] dependencies_reg [0:7];
reg [15:0] min_time_reg;
reg done_reg;
reg [2:0] counter;
reg [15:0] current_critical;
reg [2:0] eliminate_step;
reg [2:0] state;
parameter IDLE = 3'd0,
        BUILD_GRAPH = 1'd1,
        COMPUTE_ORIGINAL = 2'd2,
        TRY_ELIMINATE = 3'd3,
        COMPUTE_ELIMINATED = 4'd4,
        UPDATE_MIN = 5'd5,
        DONE = 6'd6;
function [15:0] compute_critical_path;
   input [7:0] temp_step_times [0:7];
   input [7:0] dependencies_reg [0:7];
   input [2:0] N;
   reg [15:0] dist [0:7];
   always @(*) begin
dist[0] = temp_step_times[0];
for (int i=1; i<N; i++) dist[i] = 0;
   end

for (int j=0; j<7; j++) begin
for (int v=0; v<N; v++) begin
for (int u=0; u<N; u++) begin
if (dependencies_reg[v] & (1<<u)) begin
if (dist[u] + temp_step_times[v] > dist[v]) begin
dist[v] = dist[u] + temp_step_times[v];
end
end
end
end
end
return dist[N-1];
endfunction
always_ff @(posedge clk)
   if (!rst_n) begin
state <= IDLE;
min_time_reg <= 0;
done_reg <=0;
step_count_reg <=0;
step_times_reg <=0;
dependencies_reg <=0;
counter <=0;
current_critical <=0;
eliminate_step <=0;
   end else begin
      case (state)
         IDLE: 
            if (start) begin
               state <= BUILD_GRAPH;
            end
            else state <= IDLE;
         BUILD_GRAPH:
            step_count_reg <= step_count;
step_times_reg <= step_times;
dependencies_reg <= dependencies;
counter <=0;
min_time_reg <= (1<<15)-1;
current_critical <=0;
eliminate_step <=0;
state <= COMPUTE_ORIGINAL;
         COMPUTE_ORIGINAL:
            state <= TRY_ELIMINATE;
         TRY_ELIMINATE:
            if (counter < step_count_reg) begin
               eliminate_step <= counter;
               state <= COMPUTE_ELIMINATED;
            end else begin
               state <= DONE;
            end
         COMPUTE_ELIMINATED:
            reg [7:0] temp_step_times [0:7];
            always @(*) begin
               for (int i=0; i<step_count_reg; i++) begin
                  temp_step_times[i] = step_times_reg[i];
               end
               temp_step_times[eliminate_step] = 0;
            end
            current_critical = compute_critical_path(temp_step_times, dependencies_reg, step_count_reg);
            state <= UPDATE_MIN;
         UPDATE_MIN:
            if (current_critical < min_time_reg) begin
               min_time_reg <= current_critical;
            end
            counter <= counter +1;
            if (counter < step_count_reg) begin
               state <= TRY_ELIMINATE;
            end else begin
               state <= DONE;
               done_reg <=1;
            end
         DONE:
            done_reg <=1;
            state <= DONE;
      endcase
   end
assign min_time = min_time_reg;
assign done = done_reg;
endmodule