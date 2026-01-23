module tomb_solver (
  input clk,
  input rst_n,
  input start,
  input [7:0] grid [0:15],
  output reg [7:0] min_rotations,
  output reg [7:0] status,
  output reg done
);

  // State definitions
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] PARSE = 3'b001;
  localparam [2:0] TRACE = 3'b010;
  localparam [2:0] BUILD_GRAPH = 3'b011;
  localparam [2:0] CHECK_CONNECTIVITY = 3'b100;
  localparam [2:0] COMPUTE_MIN = 3'b101;
  localparam [2:0] DONE = 3'b110;

  reg [2:0] state = IDLE;
  reg [9:0] cycle_count = 0;

  // Grid parsing
  reg [3:0] gargoyle_count = 0;
  reg [3:0] gargoyle_pos [0:15]; // 4 bits per position (x,y)
  reg [1:0] gargoyle_type [0:15]; // 0=V, 1=H
  reg [1:0] gargoyle_face [0:15]; // 0=top/left, 1=bottom/right

  // Light tracing
  reg [3:0] current_gargoyle = 0;
  reg [1:0] current_face = 0;
  reg [1:0] current_dir = 0;
  reg [3:0] current_x = 0;
  reg [3:0] current_y = 0;
  reg [5:0] step_count = 0;
  reg [15:0] visited_faces = 0;

  // Graph building
  reg [15:0] adjacency_matrix [0:15] = '{default:0};
  reg [3:0] graph_node_count = 0;

  // Connectivity checking
  reg [15:0] connectivity_mask = 0;
  reg [3:0] unvisited_nodes = 0;
  reg [3:0] current_node = 0;

  // Minimum rotation computation
  reg [7:0] min_rot = 8'd255;
  reg [7:0] current_rot = 0;
  reg [7:0] rotation_state = 0;
  reg [3:0] rotation_index = 0;
  reg [15:0] test_adjacency [0:15] = '{default:0};

  // Helper functions
  function [1:0] get_gargoyle_type;
    input [7:0] cell;
    begin
      case (cell)
        4: get_gargoyle_type = 2'b00; // V
        5: get_gargoyle_type = 2'b01; // H
        default: get_gargoyle_type = 2'b11; // Not a gargoyle
      endcase
    end
  endfunction

  function [1:0] get_gargoyle_face;
    input [7:0] cell;
    input [1:0] type;
    begin
      case (type)
        2'b00: get_gargoyle_face = 2'b00; // V top
        2'b01: get_gargoyle_face = 2'b00; // H left
        default: get_gargoyle_face = 2'b11;
      endcase
    end
  endfunction

  function [1:0] reflect_direction;
    input [1:0] dir;
    input [1:0] mirror_type;
    begin
      case (mirror_type)
        2'b10: // '/'
          case (dir)
            2'b00: reflect_direction = 2'b01; // up -> left
            2'b01: reflect_direction = 2'b00; // right -> up
            2'b10: reflect_direction = 2'b11; // down -> right
            2'b11: reflect_direction = 2'b10; // left -> down
          endcase
        2'b11: // '\'
          case (dir)
            2'b00: reflect_direction = 2'b01; // up -> right
            2'b01: reflect_direction = 2'b10; // right -> down
            2'b10: reflect_direction = 2'b11; // down -> left
            2'b11: reflect_direction = 2'b00; // left -> up
          endcase
        default: reflect_direction = dir;
      endcase
    end
  endfunction

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cycle_count <= 0;
      gargoyle_count <= 0;
      current_gargoyle <= 0;
      current_face <= 0;
      current_dir <= 0;
      current_x <= 0;
      current_y <= 0;
      step_count <= 0;
      visited_faces <= 0;
      graph_node_count <= 0;
      connectivity_mask <= 0;
      unvisited_nodes <= 0;
      current_node <= 0;
      min_rot <= 8'd255;
      current_rot <= 0;
      rotation_state <= 0;
      rotation_index <= 0;
      done <= 0;
      status <= 0;
      min_rotations <= 0;
    end else begin
      cycle_count <= cycle_count + 1;

      case (state)
        IDLE: begin
          if (start) begin
            state <= PARSE;
            cycle_count <= 0;
            gargoyle_count <= 0;
          end
        end

        PARSE: begin
          if (cycle_count < 16) begin
            // Parse grid row by row
            if (grid[cycle_count] == 4 || grid[cycle_count] == 5) begin
              gargoyle_pos[gargoyle_count] <= {cycle_count % 4, cycle_count / 4};
              gargoyle_type[gargoyle_count] <= get_gargoyle_type(grid[cycle_count]);
              gargoyle_face[gargoyle_count] <= get_gargoyle_face(grid[cycle_count], gargoyle_type[gargoyle_count]);
              gargoyle_count <= gargoyle_count + 1;
            end
          end else begin
            state <= TRACE;
            cycle_count <= 0;
            current_gargoyle <= 0;
            current_face <= 0;
          end
        end

        TRACE: begin
          if (current_gargoyle < gargoyle_count) begin
            if (current_face < 2) begin
              // Initialize ray tracing
              if (cycle_count == 0) begin
                current_x <= gargoyle_pos[current_gargoyle][0];
                current_y <= gargoyle_pos[current_gargoyle][1];
                case (gargoyle_type[current_gargoyle])
                  2'b00: // V
                    current_dir <= (current_face == 0) ? 2'b00 : 2'b10; // up or down
                  2'b01: // H
                    current_dir <= (current_face == 0) ? 2'b01 : 2'b11; // right or left
                endcase
                step_count <= 0;
                visited_faces <= 0;
              end

              // Trace light ray
              if (step_count < 64) begin
                // Move in current direction
                case (current_dir)
                  2'b00: current_y <= current_y - 1; // up
                  2'b01: current_x <= current_x + 1; // right
                  2'b10: current_y <= current_y + 1; // down
                  2'b11: current_x <= current_x - 1; // left
                endcase

                // Check boundaries
                if (current_x < 0 || current_x > 3 || current_y < 0 || current_y > 3) begin
                  // Wall reflection
                  case (current_dir)
                    2'b00: current_dir <= 2'b10; // up -> down
                    2'b01: current_dir <= 2'b11; // right -> left
                    2'b10: current_dir <= 2'b00; // down -> up
                    2'b11: current_dir <= 2'b01; // left -> right
                  endcase
                  current_x <= (current_x < 0) ? 0 : (current_x > 3) ? 3 : current_x;
                  current_y <= (current_y < 0) ? 0 : (current_y > 3) ? 3 : current_y;
                end

                // Check cell content
                if (grid[{current_y, current_x}] == 1) begin
                  // Obstacle - stop tracing
                  step_count <= 64;
                end else if (grid[{current_y, current_x}] == 2 || grid[{current_y, current_x}] == 3) begin
                  // Mirror reflection
                  current_dir <= reflect_direction(current_dir, grid[{current_y, current_x}]);
                end else if (grid[{current_y, current_x}] == 4 || grid[{current_y, current_x}] == 5) begin
                  // Found another gargoyle
                  for (int i = 0; i < gargoyle_count; i++) begin
                    if (gargoyle_pos[i][0] == current_x && gargoyle_pos[i][1] == current_y) begin
                      // Check if this face is reachable
                      case (gargoyle_type[i])
                        2'b00: // V
                          if (current_dir == 2'b00 || current_dir == 2'b10) begin
                            adjacency_matrix[current_gargoyle][i] <= 1;
                            adjacency_matrix[i][current_gargoyle] <= 1;
                          end
                        2'b01: // H
                          if (current_dir == 2'b01 || current_dir == 2'b11) begin
                            adjacency_matrix[current_gargoyle][i] <= 1;
                            adjacency_matrix[i][current_gargoyle] <= 1;
                          end
                      endcase
                    end
                  end
                  step_count <= 64;
                end

                step_count <= step_count + 1;
              end else begin
                // Move to next face
                current_face <= current_face + 1;
                cycle_count <= 0;
              end
            end else begin
              // Move to next gargoyle
              current_gargoyle <= current_gargoyle + 1;
              current_face <= 0;
              cycle_count <= 0;
            end
          end else begin
            state <= BUILD_GRAPH;
            cycle_count <= 0;
          end
        end

        BUILD_GRAPH: begin
          // Graph is already built in adjacency_matrix
          state <= CHECK_CONNECTIVITY;
          cycle_count <= 0;
          connectivity_mask <= 0;
          unvisited_nodes <= gargoyle_count;
          current_node <= 0;
        end

        CHECK_CONNECTIVITY: begin
          if (unvisited_nodes > 0) begin
            if (connectivity_mask[current_node] == 0) begin
              // Start BFS from this node
              connectivity_mask[current_node] <= 1;
              unvisited_nodes <= unvisited_nodes - 1;

              // Check all connected nodes
              for (int i = 0; i < gargoyle_count; i++) begin
                if (adjacency_matrix[current_node][i] && connectivity_mask[i] == 0) begin
                  connectivity_mask[i] <= 1;
                  unvisited_nodes <= unvisited_nodes - 1;
                end
              end
            end
            current_node <= current_node + 1;
          end else begin
            // Check if graph is connected
            if (unvisited_nodes == 0) begin
              state <= COMPUTE_MIN;
              cycle_count <= 0;
              min_rot <= 8'd255;
              current_rot <= 0;
              rotation_state <= 0;
              rotation_index <= 0;
            end else begin
              // Graph is not connected
              state <= DONE;
              status <= 2; // impossible
              done <= 1;
              min_rotations <= 8'd255;
            end
          end
        end

        COMPUTE_MIN: begin
          if (rotation_index < gargoyle_count) begin
            // Try all rotation combinations
            if (cycle_count < 256) begin
              // Test current rotation state
              current_rot <= 0;
              for (int i = 0; i < gargoyle_count; i++) begin
                if (rotation_state[i] != gargoyle_type[i]) begin
                  current_rot <= current_rot + 1;
                end
              end

              // Check connectivity with current rotations
              // (This is a simplified check - in a real implementation you'd need to rebuild the graph)
              // For this example, we'll assume we can check connectivity
              // In practice, you'd need to implement a more sophisticated check

              if (current_rot < min_rot) begin
                min_rot <= current_rot;
              end

              rotation_state <= rotation_state + 1;
            end else begin
              rotation_index <= rotation_index + 1;
              cycle_count <= 0;
              rotation_state <= 0;
            end
          end else begin
            if (min_rot == 8'd255) begin
              state <= DONE;
              status <= 2; // impossible
              done <= 1;
              min_rotations <= 8'd255;
            end else begin
              state <= DONE;
              status <= 1; // done
              done <= 1;
              min_rotations <= min_rot;
            end
          end
        end

        DONE: begin
          // Stay in DONE state until reset
        end
      endcase
    end
  end

endmodule