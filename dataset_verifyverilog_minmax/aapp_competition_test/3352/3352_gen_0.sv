module magic_color_counter (
  input clk,
  input rst_n,
  input start,
  input [2:0] node_id,
  input [1:0] cmd_data,
  // Config inputs (set during reset)
  input [2:0] parents [1:7],
  input [1:0] init_colors [0:7],
  // Outputs
  output logic [2:0] magic_count,
  output logic done
);
  // Constants
  localparam NODE_W = 3;        // up to 8 nodes (3-bit addresses)
  localparam COL_W  = 2;        // 4 possible colors (2-bit)
  localparam Q_SIZE = 8;        // queue size equals number of nodes
  localparam MAX_NODES = 8;     // total nodes

  // Internal state: current colors (maintained across operations)
  logic [COL_W-1:0] cur_colors [0:7];

  // Reset state machine
  typedef enum logic [1:0] {RST_IDLE=2'b00, RST_LOAD=2'b01, RST_WAIT=2'b10} rst_state_t;
  rst_state_t rst_state, rst_next;
  logic [2:0] rst_index;

  // Traversal state machine
  typedef enum logic [1:0] {T_IDLE=2'b00, T_GATHER=2'b01, T_PROC=2'b10, T_DONE=2'b11} t_state_t;
  t_state_t t_state, t_next;
  logic t_active;
  logic [NODE_W-1:0] q_mem [0:Q_SIZE-1];
  logic [NODE_W-1:0] q_head, q_tail;
  logic q_empty;
  logic [2:0] pop_node;     // current node being processed
  logic [NODE_W-1:0] gen_idx; // child index being tested during gather
  logic gen_child_valid;
  logic [2:0] gen_child;
  logic pop_en, q_push, push_child_valid;
  logic [2:0] push_child;
  logic [NODE_W-1:0] head_reg; // pipeline head (children of popped node)
  logic head_vld;
  logic head_next_vld;
  logic [NODE_W-1:0] head_next;
  logic visited [0:7];
  logic [3:0] parity_color; // 4 bits, one per color (odd parity -> 1)

  // Two-stage traversal control (max 16 cycles)
  logic gather_done;
  logic [3:0] cycle_cnt;
  logic cycle_inc;
  logic cycle_rst;

  // Combinational: child generation for a given node
  // For node p, children are q in [0..7] where parents[q] == p
  // - also exclude self and invalid parents (255)
  always_comb begin
    gen_idx = 0;
    gen_child_valid = 1'b0;
    gen_child = 3'b0;
    // scan all nodes to find children
    for (int i = 0; i < MAX_NODES; i++) begin
      logic [2:0] p = parents[i];
      if (i == node_id) begin
        // skip self (not a child)
      end else if (p == node_id) begin
        gen_idx = i[2:0];
        gen_child_valid = 1'b1;
        gen_child = i[2:0];
        // break after first found (stage will iterate with gen_idx_next)
      end
    end
    // If no children, gen_child_valid remains 0
  end

  // gen_idx increments by 1 each gather cycle to search for next child
  logic [2:0] gen_idx_next;
  assign gen_idx_next = (t_state == T_GATHER) ? (gen_idx + 3'b001) : 3'b0;

  // Combinational: child list for a popped node (head pipeline)
  // Same logic as above, but driven by pop_node
  always_comb begin
    head_next_vld = 1'b0;
    head_next = 3'b0;
    for (int i = 0; i < MAX_NODES; i++) begin
      if (parents[i] == pop_node) begin
        head_next_vld = 1'b1;
        head_next = i[2:0];
      end
    end
  end

  // Queue empty flag
  assign q_empty = (q_head == q_tail);

  // BFS queue push
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      q_mem <= '{default: '0};
      q_head <= 3'b0;
      q_tail <= 3'b0;
    end else begin
      if (cycle_rst) begin
        q_head <= 3'b0;
        q_tail <= 3'b0;
        q_mem <= '{default: '0};
      end else if (q_push) begin
        q_mem[q_tail] <= push_child;
        q_tail <= q_tail + 3'b001;
      end
    end
  end

  // BFS queue pop
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pop_node <= 3'b0;
    end else begin
      if (cycle_rst) begin
        pop_node <= 3'b0;
      end else if (pop_en) begin
        pop_node <= q_mem[q_head];
      end
    end
  end

  // Pipeline head (children of popped node) and valid
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      head_vld <= 1'b0;
      head_reg <= 3'b0;
    end else begin
      if (cycle_rst) begin
        head_vld <= 1'b0;
        head_reg <= 3'b0;
      end else if (pop_en) begin
        head_vld <= head_next_vld;
        head_reg <= head_next;
      end
    end
  end

  // Cycle counter (0..15, stops at 15)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) cycle_cnt <= 4'b0;
    else if (cycle_rst) cycle_cnt <= 4'b0;
    else if (cycle_inc) cycle_cnt <= cycle_cnt + 4'b1;
  end

  // Traversal active flag
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) t_active <= 1'b0;
    else if (start) t_active <= 1'b1;
    else if ((t_next == T_IDLE) || (cycle_cnt == 4'd15)) t_active <= 1'b0;
  end

  // Traversal state machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) t_state <= T_IDLE;
    else t_state <= t_next;
  end

  always_comb begin
    // defaults
    t_next = t_state;
    pop_en = 1'b0;
    q_push = 1'b0;
    push_child = 3'b0;
    push_child_valid = 1'b0;
    gather_done = 1'b0;
    cycle_inc = 1'b0;
    cycle_rst = 1'b0;
    done = 1'b0;

    unique case (t_state)
      T_IDLE: begin
        cycle_rst = 1'b1; // clear queue/head, reset cycle
        if (start) begin
          t_next = T_GATHER;
        end else begin
          t_next = T_IDLE;
        end
      end

      T_GATHER: begin
        // Phase 1: gather children of root, add to queue
        cycle_inc = 1'b1;
        // On first cycle of T_GATHER, root_id is on node_id input
        // For root we simply increment gen_idx each cycle and push children found
        if (gen_child_valid) begin
          q_push = 1'b1;
          push_child = gen_child;
          push_child_valid = 1'b1;
        end
        // Move to T_PROC after 8 cycles (enough to scan all potential children)
        if (cycle_cnt == 4'd7) begin
          gather_done = 1'b1;
          t_next = T_PROC;
        end else begin
          t_next = T_GATHER;
        end
      end

      T_PROC: begin
        cycle_inc = 1'b1;
        // pop and process one node per cycle
        if (!q_empty) pop_en = 1'b1;

        // If a head exists (children of last popped), try to push
        if (head_vld) begin
          q_push = 1'b1;
          push_child = head_reg;
          push_child_valid = 1'b1;
        end

        // finish if queue empty and no pending head
        if (q_empty && !head_vld) begin
          t_next = T_DONE;
        end else begin
          t_next = T_PROC;
        end
      end

      T_DONE: begin
        done = 1'b1;
        t_next = T_IDLE;
      end
    endcase
  end

  // Reset/load state machine: parents and initial colors
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rst_state <= RST_IDLE;
      rst_index <= 3'b0;
    end else begin
      rst_state <= rst_next;
      if (rst_state == RST_LOAD) rst_index <= rst_index + 3'b001;
    end
  end

  always_comb begin
    rst_next = rst_state;
    case (rst_state)
      RST_IDLE: rst_next = (!rst_n) ? RST_LOAD : RST_IDLE;
      RST_LOAD: rst_next = (rst_index == 3'b111) ? RST_WAIT : RST_LOAD;
      RST_WAIT: rst_next = RST_IDLE;
    endcase
  end

  // Load parents and init_colors into internal registers on reset
  logic [2:0] parents_r [1:7];
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      parents_r[1] <= 3'b0; parents_r[2] <= 3'b0; parents_r[3] <= 3'b0;
      parents_r[4] <= 3'b0; parents_r[5] <= 3'b0; parents_r[6] <= 3'b0; parents_r[7] <= 3'b0;
      for (int i = 0; i < 8; i++) cur_colors[i] <= 2'b0;
    end else begin
      if (rst_state == RST_LOAD) begin
        parents_r[rst_index] <= parents[rst_index];
      end
      // Colors are loaded once when rst_index wraps to 0 (after done)
      if (rst_state == RST_LOAD && rst_index == 3'b0) begin
        for (int i = 0; i < 8; i++) cur_colors[i] <= init_colors[i];
      end
    end
  end

  // Operation: update or query on start pulse
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      magic_count <= 3'b0;
    end else begin
      // Color update on start (cmd_data != 2'b00)
      if (start && (cmd_data != 2'b00)) begin
        cur_colors[node_id] <= (cmd_data - 2'b01); // 01->0, 10->1, 11->2
      end
      // Query result latched on done
      if ((t_next == T_DONE) && (cmd_data == 2'b00)) begin
        magic_count <= parity_color;
      end
    end
  end

  // Combinational: dynamic child for processing (used by gen logic during GATHER)
  logic [2:0] node_for_gather;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) node_for_gather <= 3'b0;
    else if (t_state == T_IDLE && start) node_for_gather <= node_id;
  end

  // Overwrite gen logic to use node_for_gather during gather (uses pop_node later)
  // Re-wire gen logic by overriding earlier with node_for_gather during T_GATHER
  always_comb begin
    // Default to previous gen (parents array) but switch based on t_state
    if (t_state == T_GATHER) begin
      gen_idx = 0;
      gen_child_valid = 1'b0;
      gen_child = 3'b0;
      for (int i = 0; i < MAX_NODES; i++) begin
        if (i == node_for_gather) begin
          // skip self
        end else if (parents[i] == node_for_gather) begin
          gen_idx = i[2:0];
          gen_child_valid = 1'b1;
          gen_child = i[2:0];
        end
      end
    end
    // Else gen_* keep the values computed earlier for pop_node (not used when not in GATHER)
  end

  // Visited tracking (one-bit per node)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 8; i++) visited[i] <= 1'b0;
    end else begin
      if (t_state == T_IDLE && start) begin
        for (int i = 0; i < 8; i++) visited[i] <= 1'b0;
        visited[node_id] <= 1'b1;
      end else if (t_state == T_GATHER && gen_child_valid) begin
        visited[gen_child] <= 1'b1;
      end else if (t_state == T_PROC && head_vld) begin
        visited[head_reg] <= 1'b1;
      end
    end
  end

  // Magic count combinational parity
  always_comb begin
    // Count nodes with odd occurrences of each color using parity of the color in the subtree
    // Only nodes in the visited set are considered part of the subtree (includes root)
    parity_color = 4'b0;
    for (int i = 0; i < 8; i++) begin
      if (visited[i]) begin
        case (cur_colors[i])
          2'b00: parity_color[0] = ~parity_color[0];
          2'b01: parity_color[1] = ~parity_color[1];
          2'b10: parity_color[2] = ~parity_color[2];
          2'b11: parity_color[3] = ~parity_color[3];
        endcase
      end
    end
  end

endmodule
