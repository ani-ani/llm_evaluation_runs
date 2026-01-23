module tree_lis_solver (
  input clk,
  input rst_n,
  input start,
  input valid_in,
  input [15:0] node_label,
  input [2:0] node_parent,
  output reg [3:0] max_length,
  output reg [15:0] path_count,
  output reg done
);

  parameter MOD = 11092019;
  parameter N = 8;
  parameter IDLE = 3'b000;
  parameter LOAD_NODE = 3'b001;
  parameter PROCESS_ANCESTORS = 3'b010;
  parameter UPDATE_GLOBAL = 3'b011;
  parameter DONE = 3'b100;

  reg [2:0] state = IDLE;
  reg [2:0] current_node = 0;
  reg [2:0] ancestor_index = 0;
  reg [3:0] len [0:N-1];
  reg [15:0] cnt [0:N-1];
  reg [3:0] global_max = 0;
  reg [15:0] global_count = 0;
  reg node_processed = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_node <= 0;
      ancestor_index <= 0;
      max_length <= 0;
      path_count <= 0;
      done <= 0;
      node_processed <= 0;
      for (integer i = 0; i < N; i = i + 1) begin
        len[i] <= 0;
        cnt[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD_NODE;
            current_node <= 0;
            node_processed <= 0;
            global_max <= 0;
            global_count <= 0;
          end
        end
        LOAD_NODE: begin
          if (valid_in) begin
            if (node_parent == 0 && current_node == 0) begin
              len[0] <= 1;
              cnt[0] <= 1;
              state <= UPDATE_GLOBAL;
            end else begin
              len[current_node] <= 1;
              cnt[current_node] <= 1;
              ancestor_index <= node_parent;
              state <= PROCESS_ANCESTORS;
            end
          end
        end
        PROCESS_ANCESTORS: begin
          if (ancestor_index == 0) begin
            state <= UPDATE_GLOBAL;
          end else begin
            if (node_label <= node_label) begin
              if (len[ancestor_index] + 1 > len[current_node]) begin
                len[current_node] <= len[ancestor_index] + 1;
                cnt[current_node] <= cnt[ancestor_index];
              end else if (len[ancestor_index] + 1 == len[current_node]) begin
                cnt[current_node] <= (cnt[current_node] + cnt[ancestor_index]) % MOD;
              end
            end
            ancestor_index <= ancestor_index - 1;
          end
        end
        UPDATE_GLOBAL: begin
          if (len[current_node] > global_max) begin
            global_max <= len[current_node];
            global_count <= cnt[current_node];
          end else if (len[current_node] == global_max) begin
            global_count <= (global_count + cnt[current_node]) % MOD;
          end
          current_node <= current_node + 1;
          node_processed <= node_processed + 1;
          if (node_processed == N - 1) begin
            state <= DONE;
          end else begin
            state <= LOAD_NODE;
          end
        end
        DONE: begin
          done <= 1;
          max_length <= global_max;
          path_count <= global_count;
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule