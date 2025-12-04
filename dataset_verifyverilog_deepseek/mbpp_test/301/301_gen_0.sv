module dict_depth_calculator (
  input clk,
  input rst_n,
  input start,
  input [3:0] max_nodes,
  input [63:0] node_data,
  output reg [3:0] depth_result,
  output reg done
);

typedef enum logic [1:0] {
  IDLE,
  INIT,
  PROCESS,
  DONE
} state_t;

state_t state;
reg [3:0] parent_idx [0:7];
reg [3:0] child_count [0:7];
reg [3:0] current_queue [0:7];
reg [3:0] current_queue_count;
reg [3:0] next_queue [0:7];
reg [3:0] next_queue_count;
reg [3:0] current_depth;
reg [3:0] max_depth_reg;

// Combinational next queue calculation
always_comb begin
  next_queue_count = 0;
  for (int i = 0; i < current_queue_count; i++) begin
    for (int j = 0; j < max_nodes; j++) begin
      if (parent_idx[j] == current_queue[i]) begin
        if (next_queue_count < 8) begin
          next_queue[next_queue_count] = j;
          next_queue_count = next_queue_count + 1;
        end
      end
    end
  end
end

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 0;
    depth_result <= 0;
    current_queue_count <= 0;
    current_depth <= 0;
    max_depth_reg <= 0;
    for (int i = 0; i < 8; i++) begin
      parent_idx[i] <= 4'd0;
      child_count[i] <= 4'd0;
      current_queue[i] <= 4'd0;
      next_queue[i] <= 4'd0;
    end
  end
  else begin
    case (state)
      IDLE: begin
        done <= 0;
        depth_result <= 0;
        if (start) begin
          // Unpack node data
          for (int i = 0; i < 8; i++) begin
            parent_idx[i] <= node_data[8*i +: 4];
            child_count[i] <= node_data[8*i +4 +: 4];
          end
          current_queue[0] <= 4'd0; // Initialize with root node
          current_queue_count <= 1;
          current_depth <= 4'd1;
          max_depth_reg <= 4'd1;
          state <= INIT;
        end
      end
      
      INIT: state <= PROCESS;
      
      PROCESS: begin
        if (current_queue_count > 0) begin
          // Update max depth if current_depth is greater
          if (current_depth > max_depth_reg) begin
            max_depth_reg <= current_depth;
          end
          
          if (next_queue_count > 0) begin
            current_queue <= next_queue;
            current_queue_count <= next_queue_count;
            current_depth <= current_depth + 1;
          end
          else begin
            state <= DONE;
          end
        end
        else begin
          state <= DONE;
        end
      end
      
      DONE: begin
        if (max_depth_reg > 8) depth_result <= 4'd8;
        else depth_result <= max_depth_reg;
        done <= 1;
        if (start) state <= IDLE;
      end
      
      default: state <= IDLE;
    endcase
  end
end

endmodule