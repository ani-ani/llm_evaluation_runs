module animal_sanctuary_restore(
  input clk,
  input rst_n,
  input start,
  input [1:0] correct_animal [0:3],
  input [1:0] current_count [0:3],
  input [3:0][1:0] current_animals,
  output reg [1:0] result,
  output reg done
);

  typedef enum logic [2:0] { IDLE = 3'd0, VERIFY_CORRECT = 3'd1, BUILD_GRAPH = 3'd2, CHECK_CYCLES = 3'd3, DONE = 3'd4 } state_t;
  state_t current_state, next_state;

  reg [1:0] enc_i, anim_j;
  reg [2:0] offset;
  reg [1:0] target [0:3];
  reg [1:0] misplaced_count [0:3];
  reg all_correct;
  reg multiple_targets;
  reg [1:0] total_nodes;
  reg [3:0] visited;
  reg [1:0] start_node, current_node;
  reg [2:0] step_count;
  reg [2:0] sum_counts;
  wire [1:0] current_animal = current_animals[offset][1:0];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      result <= 2'b00;
      enc_i <= 0;
      anim_j <= 0;
      offset <= 0;
      sum_counts <= 0;
      all_correct <= 1;
      multiple_targets <= 0;
      visited <= 0;
      step_count <= 0;
      start_node <= 0;
      current_node <= 0;
      total_nodes <= 0;
      for (int i=0; i<4; i++) begin
        target[i] <= 0;
        misplaced_count[i] <= 0;
      end
    end else begin
      current_state <= next_state;
      done <= (next_state == DONE);

      case (current_state)
        IDLE: begin
          if (start) begin
            enc_i <= 0;
            anim_j <= 0;
            offset <= 0;
            sum_counts <= 0;
            all_correct <= 1;
            multiple_targets <= 0;
            result <= 2'b00;
            visited <= 0;
            for (int i=0; i<4; i++) begin
              misplaced_count[i] <= 0;
              target[i] <= 0;
            end
          end
        end

        VERIFY_CORRECT: begin
          if (enc_i < 4) begin
            if (anim_j < current_count[enc_i]) begin
              if (current_animal != correct_animal[enc_i]) begin
                all_correct <= 0;
                misplaced_count[enc_i] <= misplaced_count[enc_i] + 1'd1;
                // Find target enclosure for current animal
                automatic logic [1:0] target_enclosure = 2'b00;
                for (int k=0; k<4; k++) begin
                  if (correct_animal[k] == current_animal) target_enclosure = k;
                end
                if (misplaced_count[enc_i] == 1) begin
                  target[enc_i] <= target_enclosure;
                end else if (target[enc_i] != target_enclosure) begin
                  multiple_targets <= 1;
                end
              end
              anim_j <= anim_j + 1'd1;
              offset <= offset + 1'd1;
            end else begin
              sum_counts <= sum_counts + current_count[enc_i];
              enc_i <= enc_i + 1'd1;
              anim_j <= 0;
              offset <= sum_counts + current_count[enc_i];
            end
          end
        end

        BUILD_GRAPH: begin
          automatic logic invalid = 0;
          for (int i=0; i<4; i++) begin
            if (misplaced_count[i] != 0 && misplaced_count[i] != 1) invalid = 1;
          end
          if (invalid || multiple_targets) begin
            result <= 2'b10;
            next_state <= DONE;
          end else begin
            total_nodes <= 0;
            for (int i=0; i<4; i++) begin
              if (misplaced_count[i] == 1) total_nodes <= total_nodes + 1;
            end
            automatic logic [1:0] first_node = 2'b00;
            for (int i=0; i<4; i++) begin
              if (misplaced_count[i] == 1) begin
                first_node = i;
                break;
              end
            end
            start_node <= first_node;
            current_node <= first_node;
            visited <= 0;
            visited[first_node] <= 1;
            step_count <= 0;
          end
        end

        CHECK_CYCLES: begin
          if (step_count == 0) begin
            current_node <= target[start_node];
            step_count <= 1;
            visited[target[start_node]] <= 1;
          end else if (current_node == start_node) begin
            automatic logic all_visited = 1;
            for (int i=0; i<4; i++) begin
              if (misplaced_count[i] == 1 && !visited[i]) all_visited = 0;
            end
            result <= (all_visited && step_count == total_nodes) ? 2'b01 : 2'b10;
            next_state <= DONE;
          end else if (step_count > total_nodes) begin
            result <= 2'b10;
            next_state <= DONE;
          end else begin
            current_node <= target[current_node];
            visited[current_node] <= 1;
            step_count <= step_count + 1;
          end
        end

        DONE: begin
          if (!start) next_state <= IDLE;
        end
      endcase
    end
  end

  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: if (start) next_state = VERIFY_CORRECT;
      VERIFY_CORRECT: if (enc_i == 4) next_state = all_correct ? DONE : BUILD_GRAPH;
      BUILD_GRAPH: if (next_state != DONE) next_state = CHECK_CYCLES;
      CHECK_CYCLES: if (current_node == start_node || step_count > total_nodes) next_state = DONE;
      DONE: if (!start) next_state = IDLE;
    endcase
  end

endmodule