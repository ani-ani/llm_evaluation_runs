module taboo_solver (
  input clk,
  input rst_n,
  input start,
  input [2:0] n_valid,
  input [7:0] str_len [0:7],
  input [7:0] taboo_str [0:63],
  output reg [2:0] result_len,
  output reg [255:0] result_str,
  output reg infinite,
  output reg done
);

  // Constants
  localparam MAX_NODES = 64;
  localparam MAX_DEPTH = 256;
  localparam MAX_TABOO = 8;
  localparam MAX_LEN = 8;

  // Node structure
  typedef struct {
    logic [1:0] child [0:1]; // child[0] for '0', child[1] for '1'
    logic is_terminal;
  } trie_node_t;

  // State machine
  typedef enum logic [2:0] {
    IDLE,
    BUILD_TRIE,
    FIND_CYCLES,
    FIND_LONGEST,
    DONE
  } state_t;

  // State registers
  state_t state;
  trie_node_t trie [0:MAX_NODES-1];
  logic [5:0] node_count;
  logic [5:0] current_node;
  logic [5:0] stack_ptr;
  logic [5:0] stack [0:MAX_DEPTH-1];
  logic [7:0] current_depth;
  logic [MAX_NODES-1:0] visited;
  logic [MAX_DEPTH-1:0] current_str;
  logic [MAX_DEPTH-1:0] best_str;
  logic [7:0] best_len;
  logic cycle_detected;
  logic [5:0] str_index;
  logic [2:0] taboo_index;
  logic [2:0] char_index;

  // Initialize registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      node_count <= 0;
      current_node <= 0;
      stack_ptr <= 0;
      current_depth <= 0;
      visited <= 0;
      current_str <= 0;
      best_str <= 0;
      best_len <= 0;
      cycle_detected <= 0;
      str_index <= 0;
      taboo_index <= 0;
      char_index <= 0;
      result_len <= 0;
      result_str <= 0;
      infinite <= 0;
      done <= 0;
      for (int i = 0; i < MAX_NODES; i++) begin
        trie[i].child[0] <= 0;
        trie[i].child[1] <= 0;
        trie[i].is_terminal <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= BUILD_TRIE;
            node_count <= 1; // root node
            taboo_index <= 0;
            str_index <= 0;
          end
        end

        BUILD_TRIE: begin
          if (taboo_index < n_valid) begin
            if (char_index == 0) begin
              current_node <= 0; // start from root
            end

            if (char_index < str_len[taboo_index]) begin
              logic bit = taboo_str[str_index][char_index];
              if (trie[current_node].child[bit] == 0) begin
                trie[current_node].child[bit] <= node_count;
                current_node <= node_count;
                node_count <= node_count + 1;
              end else begin
                current_node <= trie[current_node].child[bit];
              end

              if (char_index == str_len[taboo_index] - 1) begin
                trie[current_node].is_terminal <= 1;
              end

              char_index <= char_index + 1;
              str_index <= str_index + 1;
            end else begin
              taboo_index <= taboo_index + 1;
              char_index <= 0;
            end
          end else begin
            state <= FIND_CYCLES;
            current_node <= 0;
            stack_ptr <= 0;
            current_depth <= 0;
            visited <= 0;
            current_str <= 0;
            best_str <= 0;
            best_len <= 0;
            cycle_detected <= 0;
          end
        end

        FIND_CYCLES: begin
          if (stack_ptr == 0) begin
            // Start DFS from root
            stack[stack_ptr] <= 0;
            stack_ptr <= stack_ptr + 1;
            visited[0] <= 1;
            current_depth <= 1;
          end else begin
            current_node <= stack[stack_ptr - 1];
            logic found_child = 0;

            // Try '0' branch
            if (trie[current_node].child[0] != 0 && !visited[trie[current_node].child[0]]) begin
              stack[stack_ptr] <= trie[current_node].child[0];
              stack_ptr <= stack_ptr + 1;
              visited[trie[current_node].child[0]] <= 1;
              current_depth <= current_depth + 1;
              found_child <= 1;
            end

            // Try '1' branch
            if (!found_child && trie[current_node].child[1] != 0 && !visited[trie[current_node].child[1]]) begin
              stack[stack_ptr] <= trie[current_node].child[1];
              stack_ptr <= stack_ptr + 1;
              visited[trie[current_node].child[1]] <= 1;
              current_depth <= current_depth + 1;
              found_child <= 1;
            end

            // Backtrack if no children
            if (!found_child) begin
              stack_ptr <= stack_ptr - 1;
              current_depth <= current_depth - 1;
            end

            // Check for cycle
            if (stack_ptr > 1) begin
              logic [5:0] parent = stack[stack_ptr - 2];
              if (trie[parent].child[0] == current_node || trie[parent].child[1] == current_node) begin
                // This is a normal parent-child relationship, not a cycle
              end else begin
                // Check if current_node is in the path
                for (int i = 0; i < stack_ptr - 1; i++) begin
                  if (stack[i] == current_node) begin
                    cycle_detected <= 1;
                  end
                end
              end
            end

            // If we've finished DFS
            if (stack_ptr == 0) begin
              if (cycle_detected) begin
                state <= DONE;
                infinite <= 1;
                done <= 1;
              end else begin
                state <= FIND_LONGEST;
                current_node <= 0;
                stack_ptr <= 0;
                current_depth <= 0;
                visited <= 0;
                current_str <= 0;
                best_str <= 0;
                best_len <= 0;
              end
            end
          end
        end

        FIND_LONGEST: begin
          if (stack_ptr == 0) begin
            // Start DFS from root
            stack[stack_ptr] <= 0;
            stack_ptr <= stack_ptr + 1;
            visited[0] <= 1;
            current_depth <= 1;
            current_str <= 0;
          end else begin
            current_node <= stack[stack_ptr - 1];
            logic found_child = 0;

            // Try '0' branch first (for lex order)
            if (trie[current_node].child[0] != 0 && !visited[trie[current_node].child[0]] && !trie[trie[current_node].child[0]].is_terminal) begin
              stack[stack_ptr] <= trie[current_node].child[0];
              stack_ptr <= stack_ptr + 1;
              visited[trie[current_node].child[0]] <= 1;
              current_depth <= current_depth + 1;
              current_str <= {current_str[254:0], 1'b0};
              found_child <= 1;
            end

            // Try '1' branch
            if (!found_child && trie[current_node].child[1] != 0 && !visited[trie[current_node].child[1]] && !trie[trie[current_node].child[1]].is_terminal) begin
              stack[stack_ptr] <= trie[current_node].child[1];
              stack_ptr <= stack_ptr + 1;
              visited[trie[current_node].child[1]] <= 1;
              current_depth <= current_depth + 1;
              current_str <= {current_str[254:0], 1'b1};
              found_child <= 1;
            end

            // Update best path if this is a leaf
            if (!found_child && current_depth > best_len) begin
              best_len <= current_depth;
              best_str <= current_str;
            end else if (!found_child && current_depth == best_len && current_str < best_str) begin
              best_str <= current_str;
            end

            // Backtrack if no children
            if (!found_child) begin
              stack_ptr <= stack_ptr - 1;
              current_depth <= current_depth - 1;
              current_str <= current_str >> 1;
            end

            // If we've finished DFS
            if (stack_ptr == 0) begin
              state <= DONE;
              result_len <= best_len;
              result_str <= best_str;
              done <= 1;
            end
          end
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