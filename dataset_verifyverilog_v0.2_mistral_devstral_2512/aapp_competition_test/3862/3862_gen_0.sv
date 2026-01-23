module coke_mix (
  input clk,
  input rst_n,
  input start,
  input [9:0] n,
  input [3:0] k,
  input [15:0] types_data,
  output reg [9:0] result,
  output reg done
);

  // Parameters
  localparam IDLE = 3'b000;
  localparam INIT = 3'b001;
  localparam PROCESSING = 3'b010;
  localparam CALCULATE = 3'b011;
  localparam DONE = 3'b100;

  localparam MAX_NODES = 2048;
  localparam QUEUE_SIZE = 16;
  localparam MAX_CYCLES = 1024;

  // State machine
  reg [2:0] state = IDLE;
  reg [9:0] cycle_count = 0;

  // Visited and distance arrays
  reg [MAX_NODES-1:0] visited = 0;
  reg [9:0] distance [0:MAX_NODES-1];

  // Queue implementation
  reg [9:0] queue [0:QUEUE_SIZE-1];
  reg [3:0] queue_head = 0;
  reg [3:0] queue_tail = 0;
  reg [3:0] queue_count = 0;

  // Current processing node
  reg [9:0] current_node = 0;
  reg [9:0] current_distance = 0;

  // Types extraction
  reg [3:0] types [0:15];
  reg [9:0] type_diff [0:15];
  reg [3:0] num_types = 0;

  // Result tracking
  reg [9:0] min_liters = 1023;
  reg found = 0;

  // Extract types from packed data
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < 16; i = i + 1) begin
        types[i] <= 0;
        type_diff[i] <= 0;
      end
      num_types <= 0;
    end else if (start && state == IDLE) begin
      for (i = 0; i < 16; i = i + 1) begin
        types[i] <= types_data[(i*4)+3:(i*4)];
        type_diff[i] <= types[i] - n;
      end
      num_types <= k;
    end
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cycle_count <= 0;
      done <= 0;
      result <= 1023;
      found <= 0;
      min_liters <= 1023;
      queue_head <= 0;
      queue_tail <= 0;
      queue_count <= 0;
      current_node <= 0;
      current_distance <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
            cycle_count <= 0;
            done <= 0;
            result <= 1023;
            found <= 0;
            min_liters <= 1023;
          end
        end

        INIT: begin
          // Initialize visited array
          for (i = 0; i < MAX_NODES; i = i + 1) begin
            visited[i] <= 0;
            distance[i] <= 0;
          end

          // Initialize queue with starting node (0)
          queue[0] <= 1000; // Offset by 1000
          queue_head <= 0;
          queue_tail <= 1;
          queue_count <= 1;
          visited[1000] <= 1;
          distance[1000] <= 0;

          state <= PROCESSING;
          cycle_count <= 0;
        end

        PROCESSING: begin
          if (queue_count == 0 || cycle_count >= MAX_CYCLES) begin
            state <= CALCULATE;
          end else begin
            // Dequeue
            current_node <= queue[queue_head];
            current_distance <= distance[current_node];
            queue_head <= (queue_head + 1) % QUEUE_SIZE;
            queue_count <= queue_count - 1;

            // Check if we reached target
            if (current_node == 1000) begin
              if (current_distance < min_liters) begin
                min_liters <= current_distance;
                found <= 1;
              end
            end

            // Enqueue neighbors
            for (i = 0; i < num_types; i = i + 1) begin
              integer next_node = current_node + type_diff[i];
              if (next_node >= 0 && next_node < MAX_NODES && !visited[next_node]) begin
                visited[next_node] <= 1;
                distance[next_node] <= current_distance + 1;
                if (queue_count < QUEUE_SIZE) begin
                  queue[queue_tail] <= next_node;
                  queue_tail <= (queue_tail + 1) % QUEUE_SIZE;
                  queue_count <= queue_count + 1;
                end
              end
            end

            cycle_count <= cycle_count + 1;
          end
        end

        CALCULATE: begin
          if (found) begin
            result <= min_liters;
          end else begin
            result <= 1023;
          end
          done <= 1;
          state <= DONE;
        end

        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule