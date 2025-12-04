module hamster_navigator(
  input clk,
  input rst_n,
  input start,
  input [1:0] start_node,
  input [1:0] bed_node,
  input [15:0] graph_data,
  input [3:0] edge_count,
  output reg [15:0] min_time,
  output reg infinity,
  output reg done
);

  // FSM States
  enum {IDLE, CALC, DONE} state;
  
  // Internal storage
  reg [15:0] times [0:7];  // 4 nodes * 2 turns
  reg [7:0] edges [0:1];   // Max 2 edges
  reg [1:0] latched_start_node, latched_bed_node;
  reg [3:0] cycle_count;
  reg latched_start;
  
  // Edge unpacking
  wire [1:0] edge0_start = edges[0][7:6];
  wire [1:0] edge0_end = edges[0][5:4];
  wire [3:0] edge0_weight = edges[0][3:0];
  wire [1:0] edge1_start = edges[1][7:6];
  wire [1:0] edge1_end = edges[1][5:4];
  wire [3:0] edge1_weight = edges[1][3:0];
  
  // Temporaries
  reg [15:0] temp_times [0:7];
  integer i, j;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      infinity <= 1'b0;
      min_time <= 16'h0;
      latched_start <= 1'b0;
      for (i = 0; i < 8; i = i+1) times[i] <= 16'hFFFF;
    end
    else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          infinity <= 1'b0;
          latched_start <= start;
          if (start && !latched_start) begin  // start pulse
            // Latch inputs and reset state
            latched_start_node <= start_node;
            latched_bed_node <= bed_node;
            edges[0] <= graph_data[7:0];
            edges[1] <= graph_data[15:8];
            for (i = 0; i < 8; i = i+1) times[i] <= 16'hFFFF;
            times[{start_node,1'b0}] <= 16'h0;  // Start w/left turn
            cycle_count <= 4'h0;
            state <= CALC;
          end
        end
        
        CALC: begin
          // Backup current times
          for (i = 0; i < 8; i = i+1) temp_times[i] <= times[i];
          
          for (i = 0; i < 4; i = i+1) begin
            for (j = 0; j < 2; j = j+1) begin
              if (times[{i[1:0],j}] != 16'hFFFF) begin
                // Process edge 0 if valid
                if ((edge_count > 0) && (edge0_start == i)) begin
                  if (j == 0) begin  // Left turn -> minimize next
                    if ((times[{i[1:0],j}] + edge0_weight) < temp_times[{edge0_end,1'b1}])
                      temp_times[{edge0_end,1'b1}] <= times[{i[1:0],j}] + edge0_weight;
                  end
                  else begin  // Right turn -> maximize next
                    if ((times[{i[1:0],j}] + edge0_weight) > temp_times[{edge0_end,1'b0}])
                      temp_times[{edge0_end,1'b0}] <= times[{i[1:0],j}] + edge0_weight;
                  end
                end
                
                // Process edge 1 if valid
                if ((edge_count > 1) && (edge1_start == i)) begin
                  if (j == 0) begin
                    if ((times[{i[1:0],j}] + edge1_weight) < temp_times[{edge1_end,1'b1}])
                      temp_times[{edge1_end,1'b1}] <= times[{i[1:0],j}] + edge1_weight;
                  end
                  else begin
                    if ((times[{i[1:0],j}] + edge1_weight) > temp_times[{edge1_end,1'b0}])
                      temp_times[{edge1_end,1'b0}] <= times[{i[1:0],j}] + edge1_weight;
                  end
                end
              end
            end
          end
          
          // Update times and cycle count
          for (i = 0; i < 8; i = i+1) times[i] <= temp_times[i];
          cycle_count <= cycle_count + 1;
          
          // Transition condition
          if (cycle_count == 4'h8) begin
            state <= DONE;
          end
        end
        
        DONE: begin
          // Check if bed_node reached
          done <= 1'b1;
          if ((times[{latched_bed_node,1'b0}] != 16'hFFFF) || (times[{latched_bed_node,1'b1}] != 16'hFFFF)) begin
            infinity <= 1'b0;
            // Take minimum value between both turn states
            min_time <= (times[{latched_bed_node,1'b0}] < times[{latched_bed_node,1'b1}]) ? times[{latched_bed_node,1'b0}] : times[{latched_bed_node,1'b1}];
          end
          else begin
            infinity <= 1'b1;
            min_time <= 16'hFFFF;
          end
        end
      endcase
    end
  end
endmodule