module NameRankingCounter #(
    parameter MAX_NAMES = 8,
    parameter MAX_LEN = 8,
    parameter MAX_NODES = 32,
    parameter CHAR_WIDTH = 5,
    parameter MOD = 1000000007,
    parameter FACT_MAX = 8
  ) (
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    input  wire [3:0] num_names,
    input  wire [CHAR_WIDTH-1:0] names [0:MAX_NAMES-1][0:MAX_LEN-1],
    output reg [31:0] result,
    output reg done
  );

  // State definitions
  localparam [3:0] IDLE = 4'd0;
  localparam [3:0] RESET = 4'd1;
  localparam [3:0] INSERT_INIT = 4'd2;
  localparam [3:0] INSERT_NEXT_NAME = 4'd3;
  localparam [3:0] INSERT_NEXT_CHAR = 4'd4;
  localparam [3:0] INSERT_FIND_CHILD = 4'd5;
  localparam [3:0] INSERT_ALLOCATE = 4'd6;
  localparam [3:0] INSERT_LINK = 4'd7;
  localparam [3:0] INSERT_MARK_NAME = 4'd8;
  localparam [3:0] INSERT_ADVANCE = 4'd9;
  localparam [3:0] COMPUTE_INIT = 4'd10;
  localparam [3:0] COMPUTE_STACK_INIT = 4'd11;
  localparam [3:0] COMPUTE_STACK_POP = 4'd12;
  localparam [3:0] COMPUTE_PUSH_CHILDREN = 4'd13;
  localparam [3:0] COMPUTE_PROCESS = 4'd14;
  localparam [3:0] COMPUTE_UPDATE_RESULT = 4'd15;
  localparam [3:0] DONE = 4'd16;

  reg [3:0] current_state, next_state;

  // Trie node storage
  reg [CHAR_WIDTH-1:0] node_char [0:MAX_NODES-1];
  reg node_is_name [0:MAX_NODES-1];
  reg [4:0] node_first_child [0:MAX_NODES-1];
  reg [4:0] node_next_sibling [0:MAX_NODES-1];

  // Free list management
  reg [4:0] next_free_node;
  reg [4:0] root_node;
  assign root_node = 0;

  // Insertion registers
  reg [3:0] name_idx;
  reg [3:0] char_idx;
  reg [4:0] current_parent;
  reg [4:0] found_child;
  reg [CHAR_WIDTH-1:0] current_char;
  reg search_done;
  reg child_found;

  // Computation registers
  reg [4:0] stack [0:MAX_LEN];
  reg [4:0] stack_state [0:MAX_LEN];
  reg [3:0] sp;
  reg [4:0] node_being_processed;
  reg [4:0] proc_state;
  reg [31:0] size [0:MAX_NODES-1];
  reg [31:0] ways [0:MAX_NODES-1];
  reg [31:0] temp_size;
  reg [31:0] temp_ways;
  reg [4:0] child_count;
  reg [31:0] block_count;
  reg [31:0] multinomial;
  reg [4:0] remaining;
  reg [31:0] child_size;
  reg [4:0] current_child;

  // Precomputed factorials and inverses
  reg [31:0] fact [0:FACT_MAX];
  reg [31:0] inv_fact [0:FACT_MAX];

  // Helper functions
  function automatic logic [31:0] mod_add (input [31:0] a, b);
    logic [32:0] sum = a + b;
    mod_add = sum % MOD;
  endfunction

  function automatic logic [31:0] mod_mul (input [31:0] a, b);
    logic [63:0] prod = a * b;
    mod_mul = prod % MOD;
  endfunction

  function automatic logic [31:0] mod_pow (input [31:0] base, input [31:0] exp);
    logic [31:0] result = 1;
    logic [31:0] b = base;
    logic [31:0] e = exp;
    while (e > 0) begin
      if (e % 2 == 1) begin
        result = mod_mul(result, b);
      end
      b = mod_mul(b, b);
      e = e / 2;
    end
    mod_pow = result;
  endfunction

  // Initialize factorials and inverses
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      fact[0] = 1;
      for (i = 1; i <= FACT_MAX; i = i + 1) begin
        fact[i] = fact[i-1] * i;
      end
      inv_fact[0] = 1;
      for (i = 1; i <= FACT_MAX; i = i + 1) begin
        inv_fact[i] = mod_pow(fact[i], MOD - 2);
      end
    end
  end

  // State machine next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: if (start) next_state = RESET;
      RESET: next_state = INSERT_INIT;
      INSERT_INIT: next_state = INSERT_NEXT_NAME;
      INSERT_NEXT_NAME: if (name_idx >= num_names) next_state = COMPUTE_INIT;
                        else next_state = INSERT_NEXT_CHAR;
      INSERT_NEXT_CHAR: if (char_idx >= MAX_LEN || names[name_idx][char_idx] == 0) next_state = INSERT_MARK_NAME;
                        else next_state = INSERT_FIND_CHILD;
      INSERT_FIND_CHILD: if (search_done) begin
                           if (child_found) next_state = INSERT_ADVANCE;
                           else next_state = INSERT_ALLOCATE;
                         end else next_state = INSERT_FIND_CHILD;
      INSERT_ALLOCATE: next_state = INSERT_LINK;
      INSERT_LINK: next_state = INSERT_ADVANCE;
      INSERT_MARK_NAME: next_state = INSERT_NEXT_CHAR;
      INSERT_ADVANCE: next_state = INSERT_NEXT_CHAR;
      COMPUTE_INIT: next_state = COMPUTE_STACK_INIT;
      COMPUTE_STACK_INIT: next_state = COMPUTE_STACK_POP;
      COMPUTE_STACK_POP: if (sp == 0) next_state = COMPUTE_UPDATE_RESULT;
                         else next_state = COMPUTE_PUSH_CHILDREN;
      COMPUTE_PUSH_CHILDREN: if (current_child == 0) next_state = COMPUTE_PROCESS;
                             else next_state = COMPUTE_STACK_POP;
      COMPUTE_PROCESS: if (proc_state == 1) next_state = COMPUTE_STACK_POP;
                       else next_state = COMPUTE_STACK_POP;
      COMPUTE_UPDATE_RESULT: next_state = DONE;
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // State machine sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result <= 0;
      done <= 0;
      name_idx <= 0;
      char_idx <= 0;
      next_free_node <= 1;
      current_parent <= 0;
      found_child <= 0;
      current_char <= 0;
      search_done <= 0;
      child_found <= 0;
      sp <= 0;
      node_being_processed <= 0;
      proc_state <= 0;
      for (i = 0; i < MAX_NODES; i = i + 1) begin
        node_char[i] <= 0;
        node_is_name[i] <= 0;
        node_first_child[i] <= 0;
        node_next_sibling[i] <= 0;
        size[i] <= 0;
        ways[i] <= 0;
      end
      for (i = 0; i < MAX_LEN; i = i + 1) begin
        stack[i] <= 0;
        stack_state[i] <= 0;
      end
    end else begin
      current_state <= next_state;
      case (current_state)
        IDLE: begin
          done <= 0;
          if (start) begin
            name_idx <= 0;
            char_idx <= 0;
            next_free_node <= 1;
            current_parent <= root_node;
            for (i = 0; i < MAX_NODES; i = i + 1) begin
              node_first_child[i] <= 0;
              node_next_sibling[i] <= 0;
              node_is_name[i] <= 0;
            end
          end
        end
        RESET: begin
          // Additional reset if needed
        end
        INSERT_INIT: begin
          current_parent <= root_node;
        end
        INSERT_NEXT_NAME: begin
          name_idx <= name_idx + 1;
          char_idx <= 0;
          current_parent <= root_node;
        end
        INSERT_NEXT_CHAR: begin
          if (char_idx < MAX_LEN && names[name_idx][char_idx] != 0) begin
            current_char <= names[name_idx][char_idx];
            search_done <= 0;
            child_found <= 0;
            found_child <= 0;
          end
          char_idx <= char_idx + 1;
        end
        INSERT_FIND_CHILD: begin
          if (!search_done) begin
            // Search for child with current_char
            if (node_first_child[current_parent] == 0) begin
              search_done <= 1;
              child_found <= 0;
            end else begin
              reg [4:0] child_ptr;
              child_ptr = node_first_child[current_parent];
              if (node_char[child_ptr] == current_char) begin
                found_child <= child_ptr;
                search_done <= 1;
                child_found <= 1;
              end else begin
                // Continue searching siblings
                if (node_next_sibling[child_ptr] == 0) begin
                  search_done <= 1;
                  child_found <= 0;
                end else begin
                  child_ptr = node_next_sibling[child_ptr];
                end
              end
            end
          end
        end
        INSERT_ALLOCATE: begin
          // Allocate new node
          node_char[next_free_node] <= current_char;
          node_first_child[next_free_node] <= 0;
          node_next_sibling[next_free_node] <= 0;
          node_is_name[next_free_node] <= 0;
          found_child <= next_free_node;
          next_free_node <= next_free_node + 1;
        end
        INSERT_LINK: begin
          // Link new node into parent's child list
          node_next_sibling[found_child] <= node_first_child[current_parent];
          node_first_child[current_parent] <= found_child;
        end
        INSERT_MARK_NAME: begin
          // Mark node as name if we have consumed at least one character
          if (char_idx > 0) node_is_name[found_child] <= 1;
        end
        INSERT_ADVANCE: begin
          current_parent <= found_child;
        end
        COMPUTE_INIT: begin
          result <= 0;
          sp <= 0;
        end
        COMPUTE_STACK_INIT: begin
          stack[0] <= root_node;
          stack_state[0] <= 0;
          sp <= 1;
        end
        COMPUTE_STACK_POP: begin
          if (sp > 0) begin
            sp <= sp - 1;
            node_being_processed <= stack[sp];
            proc_state <= stack_state[sp];
          end
        end
        COMPUTE_PUSH_CHILDREN: begin
          // Push all children onto stack with state 0
          if (node_first_child[node_being_processed] != 0) begin
            reg [4:0] child_ptr;
            child_ptr = node_first_child[node_being_processed];
            stack[sp] <= child_ptr;
            stack_state[sp] <= 0;
            sp <= sp + 1;
            current_child <= child_ptr;
          end else begin
            current_child <= 0;
          end
        end
        COMPUTE_PROCESS: begin
          if (proc_state == 0) begin
            // Entering node: push children and then push self with state 1
            stack[sp] <= node_being_processed;
            stack_state[sp] <= 1;
            sp <= sp + 1;
          end else begin
            // Leaving node: compute size and ways
            temp_size <= node_is_name[node_being_processed] ? 1 : 0;
            temp_ways <= 1;
            child_count <= 0;
            block_count <= temp_size;
            multinomial <= 1;
            remaining <= temp_size;
            if (node_first_child[node_being_processed] != 0) begin
              reg [4:0] child_ptr;
              child_ptr = node_first_child[node_being_processed];
              while (child_ptr != 0) begin
                temp_size <= temp_size + size[child_ptr];
                temp_ways <= mod_mul(temp_ways, ways[child_ptr]);
                child_count <= child_count + 1;
                block_count <= block_count + size[child_ptr];
                multinomial <= mod_mul(multinomial, fact[block_count]);
                multinomial <= mod_mul(multinomial, inv_fact[size[child_ptr]]);
                multinomial <= mod_mul(multinomial, inv_fact[block_count - size[child_ptr]]);
                child_ptr = node_next_sibling[child_ptr];
              end
            end
            size[node_being_processed] <= temp_size;
            ways[node_being_processed] <= mod_mul(temp_ways, multinomial);
          end
        end
        COMPUTE_UPDATE_RESULT: begin
          result <= ways[root_node];
          done <= 1;
        end
        DONE: begin
          done <= 0;
        end
      endcase
    end
  end

endmodule