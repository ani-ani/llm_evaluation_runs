module min_coke_mixer(
  input clk,
  input rst_n,
  input start,
  input [9:0] target_n,
  input [3:0] k,
  input [9:0] concentrations [0:15],
  output reg [6:0] min_liters,
  output reg done
);

  typedef enum logic [2:0] {IDLE, INIT, DEQUEUE, CHECK, ITERATE, DONE_SUCCESS, DONE_FAILURE} state_t;
  reg [2:0] state, next_state;
  
  // BFS data structures
  reg signed [7:0] current_dev;
  reg [6:0] current_steps;
  reg [3:0] i_counter;
  reg [255:0] visited;
  reg signed [7:0] base_diffs [0:15];
  
  // Queue implementation
  reg [6:0] queue_head, queue_tail;
  reg [7:0] queue_count;
  reg [14:0] queue_mem [0:127];  // {dev[7:0], steps[6:0]}
  wire queue_empty = (queue_count == 0);
  wire [127:0] _unused_queue_wire = queue_mem[0];  // Prevent width warnings
  
  // Base diff calculation
  always_comb begin
    for (int i=0; i<16; i++) begin
      automatic logic signed [10:0] diff = concentrations[i] - target_n;
      if (i < k) begin
        if (diff < -127) base_diffs[i] = -127;
        else if (diff > 127) base_diffs[i] = 127;
        else base_diffs[i] = diff[7:0];
      end
      else base_diffs[i] = 0;
    end
  end
  
  // FSM sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      min_liters <= 7'b1111111;
      done <= 0;
      visited <= 256'b0;
      queue_head <= 0;
      queue_tail <= 0;
      queue_count <= 0;
    end
    else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) state <= INIT;
        end
        
        INIT: begin
          visited <= 256'b0;
          visited[128] <= 1'b1;  // Mark zero deviation
          queue_mem[queue_tail] <= {8'sb0, 7'b0};
          queue_tail <= (queue_tail + 1) % 128;
          queue_count <= 1;
          state <= DEQUEUE;
        end
        
        DEQUEUE: begin
          if (!queue_empty) begin
            {current_dev, current_steps} <= queue_mem[queue_head];
            queue_head <= (queue_head + 1) % 128;
            queue_count <= queue_count - 1;
            state <= CHECK;
          end
          else state <= DONE_FAILURE;
        end
        
        CHECK: begin
          if (current_dev == 0 && current_steps != 0) begin
            min_liters <= current_steps;
            done <= 1;
            state <= DONE_SUCCESS;
          end
          else begin
            i_counter <= 0;
            state <= ITERATE;
          end
        end
        
        ITERATE: begin
          if (i_counter < k) begin
            automatic logic signed [7:0] new_dev = current_dev + base_diffs[i_counter];
            automatic int unsigned idx = new_dev + 128;
            
            if (idx <= 255 && !visited[idx]) begin
              visited[idx] <= 1'b1;
              if (queue_count < 128) begin
                queue_mem[queue_tail] <= {new_dev, current_steps + 1};
                queue_tail <= (queue_tail + 1) % 128;
                queue_count <= queue_count + 1;
              end
            end
            i_counter <= i_counter + 1;
          end
          else state <= DEQUEUE;
        end
        
        DONE_SUCCESS: state <= IDLE;
        DONE_FAILURE: begin
          min_liters <= 7'b1111111;
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end
  
endmodule