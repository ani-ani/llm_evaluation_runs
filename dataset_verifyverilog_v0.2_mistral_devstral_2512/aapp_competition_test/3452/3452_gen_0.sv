module maze_equivalence (
  input clk,
  input rst_n,
  input start,
  input [6:0] num_rooms,
  input [2:0] room_degree [0:15],
  input [6:0] room_neighbors [0:15][0:7],
  output reg [2:0] group_id [0:15],
  output reg [3:0] num_groups,
  output reg done,
  output reg none
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    INIT_LABELS,
    ITERATE,
    SORT_NEIGHBORS,
    COMPUTE_HASH,
    CHECK_LABELS,
    FORM_GROUPS,
    DONE
  } state_t;

  state_t state = IDLE;
  reg [4:0] iter_count = 0;
  reg [4:0] room_idx = 0;
  reg [4:0] neighbor_idx = 0;
  reg [31:0] current_labels [0:15];
  reg [31:0] new_labels [0:15];
  reg [31:0] neighbor_labels [0:7];
  reg [31:0] temp_labels [0:15];
  reg [31:0] sorted_labels [0:7];
  reg [31:0] group_labels [0:15];
  reg [3:0] group_count = 0;
  reg [3:0] current_group = 0;
  reg [3:0] group_size = 0;
  reg [3:0] min_room_in_group = 0;
  reg [3:0] group_assigned [0:15];

  // Bubble sort for neighbor labels
  reg [4:0] sort_i = 0;
  reg [4:0] sort_j = 0;
  reg [31:0] sort_temp;

  // Hash computation
  reg [31:0] hash_result;

  // Reset logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      iter_count <= 0;
      room_idx <= 0;
      neighbor_idx <= 0;
      done <= 0;
      none <= 0;
      num_groups <= 0;
      for (int i = 0; i < 16; i++) begin
        current_labels[i] <= 0;
        new_labels[i] <= 0;
        group_id[i] <= 0;
        group_assigned[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT_LABELS;
            done <= 0;
            none <= 0;
            num_groups <= 0;
          end
        end

        INIT_LABELS: begin
          if (room_idx < num_rooms) begin
            current_labels[room_idx] <= room_degree[room_idx];
            room_idx <= room_idx + 1;
          end else begin
            room_idx <= 0;
            state <= ITERATE;
            iter_count <= 0;
          end
        end

        ITERATE: begin
          if (iter_count < 16) begin
            state <= SORT_NEIGHBORS;
            room_idx <= 0;
            neighbor_idx <= 0;
          end else begin
            state <= CHECK_LABELS;
            room_idx <= 0;
          end
        end

        SORT_NEIGHBORS: begin
          if (room_idx < num_rooms) begin
            if (neighbor_idx < 8) begin
              if (room_neighbors[room_idx][neighbor_idx] != 0) begin
                neighbor_labels[neighbor_idx] <= current_labels[room_neighbors[room_idx][neighbor_idx] - 1];
              end else begin
                neighbor_labels[neighbor_idx] <= 0;
              end
              neighbor_idx <= neighbor_idx + 1;
            end else begin
              // Copy neighbor labels to sorted_labels
              for (int i = 0; i < 8; i++) begin
                sorted_labels[i] <= neighbor_labels[i];
              end
              sort_i <= 0;
              sort_j <= 0;
              state <= COMPUTE_HASH;
              neighbor_idx <= 0;
            end
          end else begin
            room_idx <= 0;
            state <= ITERATE;
            iter_count <= iter_count + 1;
          end
        end

        COMPUTE_HASH: begin
          // Simple bubble sort
          if (sort_i < 7) begin
            if (sort_j < 7 - sort_i) begin
              if (sorted_labels[sort_j] > sorted_labels[sort_j + 1]) begin
                sort_temp <= sorted_labels[sort_j];
                sorted_labels[sort_j] <= sorted_labels[sort_j + 1];
                sorted_labels[sort_j + 1] <= sort_temp;
              end
              sort_j <= sort_j + 1;
            end else begin
              sort_j <= 0;
              sort_i <= sort_i + 1;
            end
          end else begin
            // Compute hash
            hash_result <= {current_labels[room_idx], sorted_labels[0], sorted_labels[1], sorted_labels[2], sorted_labels[3], sorted_labels[4], sorted_labels[5], sorted_labels[6], sorted_labels[7]};
            new_labels[room_idx] <= hash_result;
            room_idx <= room_idx + 1;
            state <= SORT_NEIGHBORS;
          end
        end

        CHECK_LABELS: begin
          if (room_idx < num_rooms) begin
            if (current_labels[room_idx] != new_labels[room_idx]) begin
              // Labels changed, need another iteration
              for (int i = 0; i < 16; i++) begin
                current_labels[i] <= new_labels[i];
              end
              state <= ITERATE;
              iter_count <= 0;
              room_idx <= 0;
            end else begin
              room_idx <= room_idx + 1;
            end
          end else begin
            // All labels stable, form groups
            for (int i = 0; i < 16; i++) begin
              group_labels[i] <= current_labels[i];
            end
            state <= FORM_GROUPS;
            room_idx <= 0;
            group_count <= 0;
            current_group <= 0;
            group_size <= 0;
            min_room_in_group <= 0;
          end
        end

        FORM_GROUPS: begin
          if (room_idx < num_rooms) begin
            if (group_assigned[room_idx] == 0) begin
              // Find all rooms with same label
              group_size <= 1;
              min_room_in_group <= room_idx;
              group_assigned[room_idx] <= 1;
              for (int i = room_idx + 1; i < num_rooms; i++) begin
                if (group_labels[i] == group_labels[room_idx] && group_assigned[i] == 0) begin
                  group_size <= group_size + 1;
                  group_assigned[i] <= 1;
                  if (i < min_room_in_group) begin
                    min_room_in_group <= i;
                  end
                end
              end
              // Assign group ID if size >= 2
              if (group_size >= 2) begin
                current_group <= current_group + 1;
                group_id[room_idx] <= current_group;
                for (int i = 0; i < num_rooms; i++) begin
                  if (group_labels[i] == group_labels[room_idx]) begin
                    group_id[i] <= current_group;
                  end
                end
              end
            end
            room_idx <= room_idx + 1;
          end else begin
            num_groups <= current_group;
            if (current_group == 0) begin
              none <= 1;
            end
            state <= DONE;
            done <= 1;
          end
        end

        DONE: begin
          if (!start) begin
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule