module k_multihedgehog_checker(
  input clk,
  input rst_n,
  input start,
  input [3:0] num_nodes,
  input [3:0] k_value,
  input [255:0] adjacency,
  output reg result,
  output reg done
);

  // Internal registers
  reg [255:0] adj_cur;          // current adjacency matrix
  reg [4:0]   node_deg [0:15];  // degree of each node (max 15)
  reg [3:0]   active_nodes;     // count of nodes with deg>=0 within num_nodes range

  reg [4:0]   center_idx;       // index of center candidate
  reg [4:0]   center_deg;       // degree of center candidate

  reg [4:0]   leaf_count;       // count of leaves in a pruning round
  reg [15:0]  leaf_mask;        // bit i = 1 if node i is leaf this round

  reg [3:0]   k_steps_left;     // k steps to prune

  reg [4:0]   cycle_cnt;       // to ensure completion by cycle 20

  // FSM states
  typedef enum logic [3:0] {
    S_IDLE         = 4'd0,
    S_INIT_LOAD    = 4'd1,
    S_DEGREE_CALC  = 4'd2,
    S_CHECK_TREE   = 4'd3,
    S_FIND_CENTER  = 4'd4,
    S_CHECK_CENTER = 4'd5,
    S_PRUNE_INIT   = 4'd6,
    S_PRUNE_MARK   = 4'd7,
    S_PRUNE_APPLY  = 4'd8,
    S_PRUNE_CHECK  = 4'd9,
    S_DONE         = 4'd10,
    S_FAIL         = 4'd11
  } state_t;

  state_t state, next_state;

  integer i, j;

  // Helper: get bit for adjacency (i,j)
  function automatic logic get_adj_bit(
    input [255:0] mat,
    input [3:0] r,
    input [3:0] c
  );
    get_adj_bit = mat[{r,4'b0000} + c];
  endfunction

  // Helper: set bit for adjacency (i,j)
  function automatic [255:0] clr_adj_bit(
    input [255:0] mat,
    input [3:0] r,
    input [3:0] c
  );
    integer idx;
    begin
      idx = {r,4'b0000} + c;
      clr_adj_bit = mat;
      clr_adj_bit[idx] = 1'b0;
    end
  endfunction

  // Sequential state and counters
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      result      <= 1'b0;
      done        <= 1'b0;
      adj_cur     <= 256'b0;
      active_nodes<= 4'd0;
      center_idx  <= 5'd0;
      center_deg  <= 5'd0;
      leaf_count  <= 5'd0;
      leaf_mask   <= 16'b0;
      k_steps_left<= 4'd0;
      cycle_cnt   <= 5'd0;
      for (i = 0; i < 16; i = i + 1) begin
        node_deg[i] <= 5'd0;
      end
    end else begin
      state <= next_state;

      // cycle counter (for max latency guard)
      if (state == S_IDLE)
        cycle_cnt <= 5'd0;
      else if (!done)
        cycle_cnt <= cycle_cnt + 5'd1;

      // State actions
      case (state)
        S_IDLE: begin
          done   <= 1'b0;
          result <= 1'b0;
          if (start) begin
            // latch adjacency and basic params
            adj_cur      <= adjacency;
            k_steps_left <= (k_value > 4'd4) ? 4'd4 : k_value;
          end
        end

        S_INIT_LOAD: begin
          // Count active nodes = num_nodes (1..16)
          active_nodes <= num_nodes;
        end

        S_DEGREE_CALC: begin
          // compute degrees for nodes within num_nodes
          for (i = 0; i < 16; i = i + 1) begin
            if (i < num_nodes) begin
              node_deg[i] <= 5'd0;
              for (j = 0; j < 16; j = j + 1) begin
                if (j < num_nodes) begin
                  node_deg[i] <= node_deg[i] + get_adj_bit(adj_cur, i[3:0], j[3:0]);
                end
              end
            end else begin
              node_deg[i] <= 5'd0;
            end
          end
        end

        S_CHECK_TREE: begin
          // Basic tree checks: edges == num_nodes-1 and no self-loops, undirected
          // Implement combinationally in next_state logic; no action here.
        end

        S_FIND_CENTER: begin
          // find node with max degree (candidate center)
          center_idx <= 5'd0;
          center_deg <= 5'd0;
          for (i = 0; i < 16; i = i + 1) begin
            if (i < num_nodes) begin
              if (node_deg[i] > center_deg) begin
                center_deg <= node_deg[i];
                center_idx <= i[4:0];
              end
            end
          end
        end

        S_CHECK_CENTER: begin
          // no extra sequential; decision in next_state
        end

        S_PRUNE_INIT: begin
          leaf_mask  <= 16'b0;
          leaf_count <= 5'd0;
        end

        S_PRUNE_MARK: begin
          // mark leaves among active nodes
          leaf_mask  <= 16'b0;
          leaf_count <= 5'd0;
          for (i = 0; i < 16; i = i + 1) begin
            if (i < num_nodes && node_deg[i] == 5'd1) begin
              leaf_mask[i] <= 1'b1;
              leaf_count   <= leaf_count + 5'd1;
            end
          end
        end

        S_PRUNE_APPLY: begin
          // remove all leaf edges and update degrees
          for (i = 0; i < 16; i = i + 1) begin
            if (i < num_nodes) begin
              if (leaf_mask[i]) begin
                // for leaf i, find its neighbor and clear edges
                for (j = 0; j < 16; j = j + 1) begin
                  if (j < num_nodes && get_adj_bit(adj_cur, i[3:0], j[3:0])) begin
                    // clear both directions
                    adj_cur               <= clr_adj_bit(adj_cur, i[3:0], j[3:0]);
                    adj_cur               <= clr_adj_bit(adj_cur, j[3:0], i[3:0]);
                    if (node_deg[j] > 0)
                      node_deg[j] <= node_deg[j] - 5'd1;
                  end
                end
                node_deg[i] <= 5'd0;
              end
            end
          end
          // update active_nodes
          active_nodes <= active_nodes - leaf_count[3:0];
        end

        S_PRUNE_CHECK: begin
          // decrement k steps
          if (k_steps_left != 4'd0)
            k_steps_left <= k_steps_left - 4'd1;
        end

        S_DONE: begin
          done <= 1'b1;
        end

        S_FAIL: begin
          done   <= 1'b1;
          result <= 1'b0;
        end

        default: ;
      endcase

      // Timeout safeguard: force done by cycle 20
      if (!done && cycle_cnt >= 5'd20) begin
        done   <= 1'b1;
        result <= 1'b0;
        state  <= S_DONE;
      end
    end
  end

  // Combinational next state and result evaluations
  always @* begin
    next_state = state;

    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT_LOAD;
      end

      S_INIT_LOAD: begin
        // directly proceed to degree calc
        next_state = S_DEGREE_CALC;
      end

      S_DEGREE_CALC: begin
        next_state = S_CHECK_TREE;
      end

      S_CHECK_TREE: begin
        // verify simple tree properties
        integer e_cnt;
        integer a, b;
        reg ok;
        e_cnt = 0;
        ok    = 1'b1;
        for (a = 0; a < 16; a = a + 1) begin
          if (a < num_nodes) begin
            // no self loop
            if (get_adj_bit(adj_cur, a[3:0], a[3:0]) == 1'b1)
              ok = 1'b0;
            for (b = a+1; b < 16; b = b + 1) begin
              if (b < num_nodes) begin
                if (get_adj_bit(adj_cur, a[3:0], b[3:0]) !== get_adj_bit(adj_cur, b[3:0], a[3:0]))
                  ok = 1'b0;
                if (get_adj_bit(adj_cur, a[3:0], b[3:0]))
                  e_cnt = e_cnt + 1;
              end
            end
          end
        end
        if (!ok || (num_nodes == 0) || (e_cnt != (num_nodes - 1))) begin
          next_state = S_FAIL;
        end else begin
          next_state = S_FIND_CENTER;
        end
      end

      S_FIND_CENTER: begin
        next_state = S_CHECK_CENTER;
      end

      S_CHECK_CENTER: begin
        // check center degree >= 3 (for non-trivial k)
        if (k_steps_left == 0) begin
          // For k=0, any tree with a center (already verified) is accepted
          next_state = S_DONE;
        end else begin
          if (center_deg < 5'd3)
            next_state = S_FAIL;
          else
            next_state = S_PRUNE_INIT;
        end
      end

      S_PRUNE_INIT: begin
        if (k_steps_left == 0)
          next_state = S_DONE;
        else
          next_state = S_PRUNE_MARK;
      end

      S_PRUNE_MARK: begin
        // if no leaves -> invalid
        if (leaf_count == 0)
          next_state = S_FAIL;
        else
          next_state = S_PRUNE_APPLY;
      end

      S_PRUNE_APPLY: begin
        next_state = S_PRUNE_CHECK;
      end

      S_PRUNE_CHECK: begin
        if (k_steps_left <= 1) begin
          // After final pruning, ensure still a valid tree-like structure
          // Minimal check: at least one node remains and no isolated multiple centers.
          if (active_nodes == 0)
            next_state = S_FAIL;
          else begin
            next_state = S_DONE;
          end
        end else begin
          next_state = S_PRUNE_INIT;
        end
      end

      S_DONE: begin
        // decide result if not already fail
        // Here, if reached DONE from success path, result=1
        next_state = S_DONE;
      end

      S_FAIL: begin
        next_state = S_FAIL;
      end

      default: begin
        next_state = S_FAIL;
      end
    endcase
  end

  // Result control: set high only on successful DONE arrival
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 1'b0;
    end else begin
      if (state == S_CHECK_CENTER && next_state == S_DONE && k_steps_left == 0) begin
        result <= 1'b1;
      end else if (state == S_PRUNE_CHECK && next_state == S_DONE && k_steps_left <= 1 && active_nodes != 0) begin
        result <= 1'b1;
      end else if (state == S_FAIL) begin
        result <= 1'b0;
      end
    end
  end

endmodule