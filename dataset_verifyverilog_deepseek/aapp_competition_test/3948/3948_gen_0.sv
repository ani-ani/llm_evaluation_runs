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

  typedef enum logic [2:0] {IDLE, INIT, PRUNE, CHECK, DONE} state_t;
  reg [2:0] state, next_state;
  reg [255:0] current_adjacency;
  reg [255:0] initial_adj;
  reg [3:0] k_val_reg;
  reg [3:0] step_count;
  reg [3:0] node_count_reg;
  wire [3:0] degrees [0:15];
  wire [15:0] leaf_mask;

  // Generate degree counters
  generate
    genvar i, j;
    for (i = 0; i < 16; i++) begin : degree_calc
      reg [3:0] deg;
      always_comb begin
        deg = 0;
        for (j = 0; j < 16; j++) begin
          if (current_adjacency[i*16 + j] && (j < node_count_reg)) deg = deg + 1;
        end
      end
      assign degrees[i] = deg;
    end
  endgenerate

  // Leaf mask generation
  generate
    genvar idx;
    for (idx = 0; idx < 16; idx++) begin : leaf_mask_gen
      assign leaf_mask[idx] = (degrees[idx] == 4'd1) && (idx < node_count_reg);
    end
  endgenerate

  // Next adjacency logic
  wire [255:0] next_adj;
  generate
    genvar row, col;
    for (row = 0; row < 16; row++) begin : adj_row
      for (col = 0; col < 16; col++) begin : adj_col
        assign next_adj[row*16 + col] = current_adjacency[row*16 + col] & 
                                       ~leaf_mask[row] & ~leaf_mask[col] & 
                                       (row < node_count_reg) & (col < node_count_reg);
      end
    end
  endgenerate

  // FSM transitions
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      current_adjacency <= 256'd0;
      initial_adj <= 256'd0;
      k_val_reg <= 4'd0;
      node_count_reg <= 4'd0;
      step_count <= 4'd0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          result <= 0;
          if (start) begin
            state <= INIT;
          end
        end

        INIT: begin
          node_count_reg <= num_nodes;
          k_val_reg <= k_value;
          initial_adj <= adjacency;
          current_adjacency <= 256'd0;
          for (int i = 0; i < 16; i++) begin
            if (i < num_nodes) begin
              current_adjacency[i*16 +: 16] <= adjacency[i*16 +: 16] & {(16){1'b1}} >> (16 - num_nodes);
            end else begin
              current_adjacency[i*16 +: 16] <= 16'd0;
            end
          end
          step_count <= 4'd0;
          state <= PRUNE;
        end

        PRUNE: begin
          if (step_count < k_val_reg) begin
            if (|leaf_mask) begin
              current_adjacency <= next_adj;
              step_count <= step_count + 1;
            end else begin
              state <= CHECK;
            end
          end else begin
            state <= CHECK;
          end
        end

        CHECK: begin
          automatic int valid_nodes = 0;
          automatic int center_node = -1;
          for (int i = 0; i < 16; i++) begin
            if ((degrees[i] > 0) && (i < node_count_reg)) begin
              valid_nodes++;
              center_node = i;
            end
          end
          if (valid_nodes != 1) begin
            result <= 1'b0;
          end else begin
            automatic int orig_degree = 0;
            for (int j = 0; j < 16; j++) begin
              if (initial_adj[center_node*16 + j] && (j < node_count_reg)) begin
                orig_degree++;
              end
            end
            result <= (orig_degree >= 3);
          end
          done <= 1'b1;
          state <= DONE;
        end

        DONE: begin
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule