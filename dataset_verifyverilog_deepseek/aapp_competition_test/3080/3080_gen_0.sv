module snack_distribution(
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] adjacency,
  input [2:0] k,
  input [2:0] a,
  input [2:0][2:0] targets,
  output reg [6:0] count,
  output reg done
);

// State machine definitions
enum logic [2:0] {
  IDLE,
  INIT,
  PATH_COMPUTE,
  SUBSET_GEN,
  VALIDATE,
  UPDATE_COUNT,
  DONE
} state;

// Internal registers
reg [7:0] reachable_from_root;
reg [7:0] reverse_reachable [0:7];
reg [7:0] target_mask [0:7];
reg [7:0] subset;
reg [6:0] valid_count;
reg [7:0] subset_counter;
reg [3:0] target_index;
reg [3:0] iter_count;
logic [7:0] temp_reachable;

// Functional logic
function logic [2:0] popcount(input [7:0] vec);
  popcount = '0;
  for (int i=0; i<8; i=i+1) popcount += vec[i];
endfunction

// Calculate next_subset
function [7:0] next_subset(input [7:0] current);
  logic [7:0] next;
  logic found;
  next = current;
  found = 0;
  for (int i=0; i<8; i=i+1) begin
    if (next[i] && (i==7 || !next[i+1])) begin
      next[i] = 0;
      for (int j=0; j<=i; j=j+1) next[j] = 0;
      for (int j=0; j<=popcount(current)-1; j=j+1) next[j] = 1;
      found = 1;
      break;
    end
  end
  if (!found) next = 0;
  next_subset = next;
endfunction

// Main state transitions
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 0;
    count <= 0;
    subset <= 0;
    valid_count <= 0;
    subset_counter <= 0;
    target_index <= 0;
    iter_count <= 0;
    reachable_from_root <= 8'b00000001;
    for (int i=0; i<8; i=i+1) begin
      reverse_reachable[i] <= 0;
      target_mask[i] <= 0;
    end
  end else begin
    case (state)
      IDLE: if (start) state <= INIT;

      INIT: begin
        reachable_from_root <= 8'b00000001;
        subset <= 8'b0;
        done <= 0;
        count <= 0;
        subset_counter <= 0;
        iter_count <= 0;
        target_index <= 0;
        valid_count <= 0;
        for (int i=0; i<8; i=i+1) begin
          reverse_reachable[i] <= 0;
          target_mask[i] <= 0;
        end
        state <= PATH_COMPUTE;
      end

      PATH_COMPUTE: begin
        // Forward BFS from root
        if (iter_count < 8) begin
          temp_reachable = reachable_from_root;
          for (int j=0; j<8; j=j+1) begin
            for (int i=0; i<8; i=i+1) begin
              if (adjacency[j][i] && temp_reachable[j]) temp_reachable[i] = 1;
            end
          end
          reachable_from_root <= temp_reachable;
          iter_count <= iter_count + 1;
        end else if (target_index < a) begin
          // Init reverse reach for current target
          if (iter_count == 8) begin
            reverse_reachable[target_index] <= (1 << targets[target_index]);
            iter_count <= 0;
          end else begin
            // Reverse BFS iteration
            temp_reachable = reverse_reachable[target_index];
            for (int j=0; j<8; j=j+1) begin
              for (int i=0; i<8; i=i+1) begin
                if (adjacency[i][j] && temp_reachable[j]) temp_reachable[i] = 1;
              end
            end
            reverse_reachable[target_index] <= temp_reachable;
            iter_count <= iter_count + 1;
            if (iter_count == 7) begin
              target_index <= target_index + 1;
              iter_count <= 8; // Mark to init next target
            end
          end
        end else begin
          // Finished both BFS, calculate target_mask
          for (int j=0; j<8; j=j+1) begin
            target_mask[j] <= 0;
            for (int i=0; i<a; i=i+1) begin
              if (reachable_from_root[j] && reverse_reachable[i][j]) begin
                target_mask[j][i] <= 1;
              end
            end
          end
          subset <= 0;
          for (int i=0; i<k; i=i+1) subset[i] <= 1;
          state <= SUBSET_GEN;
          subset_counter <= 0;
          valid_count <= 0;
          iter_count <= 0;
        end
      end

      SUBSET_GEN: begin
        done <= 0;
        if (popcount(subset) == k) begin
          state <= VALIDATE;
        end else begin
          subset <= next_subset(subset);
          if (subset == 0) state <= DONE;
          subset_counter <= subset_counter + 1;
        end
      end

      VALIDATE: begin
        // Check condition 1: all nodes in subset cover >=1 target
        logic cond1;
        cond1 = 1;
        for (int i=0; i<8; i=i+1) begin
          if (subset[i] && (target_mask[i] == 0)) cond1 = 0;
        end

        // Check condition 2: each target covered by exactly one node
        logic cond2;
        cond2 = 1;
        for (int t=0; t<a; t=t+1) begin
          logic [2:0] cnt;
          cnt = 0;
          for (int n=0; n<8; n=n+1) begin
            if (subset[n] && target_mask[n][t]) cnt += 1;
          end
          if (cnt != 1) cond2 = 0;
        end

        // Update count
        if (cond1 && cond2) valid_count <= valid_count + 1;
        subset <= next_subset(subset);
        state <= SUBSET_GEN;
        if (subset == 0) state <= DONE;
        subset_counter <= subset_counter + 1;
      end

      DONE: begin
        count <= valid_count;
        done <= 1;
        if (!start) state <= IDLE;
      end
    endcase

    // Timeout safeguard
    if (state != IDLE && subset_counter > 255) state <= DONE;
  end
end

endmodule