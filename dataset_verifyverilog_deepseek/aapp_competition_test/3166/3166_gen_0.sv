module tournament_disqualify(
  input clk,
  input rst_n,
  input start,
  input [15:0] adj_matrix,
  input [3:0] original_S_mask,
  output reg [2:0] result,
  output reg done
);

typedef enum logic [2:0] {
  IDLE,
  GEN_SUBSET,
  PROCESS_GRAPH,
  CHECK_CYCLE,
  FINISH
} state_t;

state_t state, next_state;
reg [1:0] current_k;
reg [3:0] subset_counter;
reg [3:0] current_subset;
reg [3:0] available_players;
reg [15:0] modified_adj;
reg [3:0][3:0] reach_reg;
reg found;

function automatic void modify_adj_matrix(
  input [3:0] disqual_mask,
  input [15:0] adj_in,
  output reg [15:0] adj_out
);
  reg [3:0][3:0] adj_2d;
  integer i, j;
begin
  adj_2d = {adj_in[15:12], adj_in[11:8], adj_in[7:4], adj_in[3:0]};
  for (i = 0; i < 4; i++) begin
    for (j = 0; j < 4; j++) begin
      if (disqual_mask[i] || disqual_mask[j]) adj_2d[i][j] = 1'b0;
    end
  end
  adj_out = {adj_2d[0], adj_2d[1], adj_2d[2], adj_2d[3]};
end
endfunction

function automatic [3:0][3:0] compute_reach(input [15:0] adj_flat);
  reg [3:0][3:0] adj_mat;
  reg [3:0][3:0] reach_mat;
  integer i, j;
begin
  adj_mat = {adj_flat[15:12], adj_flat[11:8], adj_flat[7:4], adj_flat[3:0]};
  reach_mat = adj_mat;
  
  // Floyd-Warshall unrolled
  // k=0
  for (i=0; i<4; i++) for (j=0; j<4; j++)
    reach_mat[i][j] = reach_mat[i][j] | (reach_mat[i][0] & reach_mat[0][j]);
  // k=1
  for (i=0; i<4; i++) for (j=0; j<4; j++)
    reach_mat[i][j] = reach_mat[i][j] | (reach_mat[i][1] & reach_mat[1][j]);
  // k=2
  for (i=0; i<4; i++) for (j=0; j<4; j++)
    reach_mat[i][j] = reach_mat[i][j] | (reach_mat[i][2] & reach_mat[2][j]);
  // k=3
  for (i=0; i<4; i++) for (j=0; j<4; j++)
    reach_mat[i][j] = reach_mat[i][j] | (reach_mat[i][3] & reach_mat[3][j]);
  
  return reach_mat;
end
endfunction

assign available_players = ~original_S_mask;
wire [2:0] subset_count = subset_counter[0] + subset_counter[1] + subset_counter[2] + subset_counter[3];
wire valid_subset = (subset_counter & available_players) == subset_counter && (subset_count == current_k);
wire [3:0][3:0] reach = compute_reach(modified_adj);
wire cycle_found = (reach_reg[0][0] || reach_reg[1][1] || reach_reg[2][2] || reach_reg[3][3]);

always_ff @(posedge clk or negedge rst_n) begin
  if (~rst_n) begin
    state <= IDLE;
    result <= 3'b100;
    done <= 1'b0;
    current_k <= 2'b00;
    subset_counter <= 4'b0000;
    found <= 1'b0;
  end else begin
    case (state)
      IDLE: begin
        done <= 1'b0;
        result <= 3'b100;
        if (start) begin
          state <= GEN_SUBSET;
          current_k <= 2'b00;
          subset_counter <= 4'b0000;
          found <= 1'b0;
        end
      end

      GEN_SUBSET: begin
        if (valid_subset) begin
          current_subset <= subset_counter;
          state <= PROCESS_GRAPH;
        end else begin
          if (&subset_counter) begin
            if (current_k == 2'b10) state <= FINISH;
            else begin
              current_k <= current_k + 1;
              subset_counter <= 4'b0000;
            end
          end else begin
            subset_counter <= subset_counter + 1;
          end
        end
      end

      PROCESS_GRAPH: begin
        modify_adj_matrix(original_S_mask | current_subset, adj_matrix, modified_adj);
        reach_reg <= reach;
        state <= CHECK_CYCLE;
      end

      CHECK_CYCLE: begin
        if (cycle_found) begin
          if (&subset_counter) begin
            if (current_k == 2'b10) state <= FINISH;
            else begin
              current_k <= current_k + 1;
              subset_counter <= 4'b0000;
              state <= GEN_SUBSET;
            end
          end else begin
            subset_counter <= subset_counter + 1;
            state <= GEN_SUBSET;
          end
        end else begin
          found <= 1'b1;
          state <= FINISH;
          result <= {1'b0, current_k};
        end
      end

      FINISH: begin
        done <= 1'b1;
        if (!start) state <= IDLE;
      end

      default: state <= IDLE;
    endcase
  end
end

endmodule