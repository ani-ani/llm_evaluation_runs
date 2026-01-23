module tree_optimizer (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_nodes,
  input [7:0] edges [14:0][1:0],
  output reg [2:0] best_diameter,
  output reg [2:0] remove_edge_u, remove_edge_v,
  output reg [2:0] add_edge_u, add_edge_v,
  output reg done
);

  // Parameters
  localparam IDLE = 3'b000;
  localparam COMPUTE_DISTANCES = 3'b001;
  localparam TRY_EDGES = 3'b010;
  localparam FIND_CENTERS = 3'b011;
  localparam EVALUATE = 3'b100;
  localparam UPDATE_BEST = 3'b101;
  localparam DONE_STATE = 3'b110;

  // State register
  reg [2:0] state, next_state;

  // Internal registers
  reg [2:0] current_edge_idx;
  reg [2:0] current_node_u, current_node_v;
  reg [2:0] current_center_u, current_center_v;
  reg [2:0] current_diameter;
  reg [2:0] temp_diameter;
  reg [2:0] component1_nodes [7:0];
  reg [2:0] component2_nodes [7:0];
  reg [2:0] component1_size, component2_size;
  reg [2:0] distance_matrix [7:0][7:0];
  reg [2:0] temp_distance_matrix [7:0][7:0];
  reg [2:0] adjacency_matrix [7:0][7:0];
  reg [2:0] edge_count;
  reg [2:0] i, j, k;
  reg [2:0] max_dist;
  reg [2:0] center_candidate;
  reg [2:0] max_center_dist;
  reg [2:0] temp_max_dist;
  reg [2:0] temp_node;
  reg [2:0] temp_edge_u, temp_edge_v;
  reg [2:0] temp_add_u, temp_add_v;
  reg [2:0] temp_remove_u, temp_remove_v;
  reg [2:0] temp_best_diameter;
  reg [2:0] temp_component_nodes [7:0];
  reg [2:0] temp_component_size;
  reg [2:0] temp_center;
  reg [2:0] temp_dist;
  reg [2:0] temp_max;
  reg [2:0] temp_i, temp_j;
  reg [2:0] temp_k;
  reg [2:0] temp_edge_idx;
  reg [2:0] temp_node_idx;
  reg [2:0] temp_component_idx;
  reg [2:0] temp_center_idx;
  reg [2:0] temp_diameter_idx;
  reg [2:0] temp_edge_count;
  reg [2:0] temp_edge_u_idx, temp_edge_v_idx;
  reg [2:0] temp_add_u_idx, temp_add_v_idx;
  reg [2:0] temp_remove_u_idx, temp_remove_v_idx;
  reg [2:0] temp_best_diameter_idx;
  reg [2:0] temp_component_nodes_idx [7:0];
  reg [2:0] temp_component_size_idx;
  reg [2:0] temp_center_idx_idx;
  reg [2:0] temp_dist_idx;
  reg [2:0] temp_max_idx;
  reg [2:0] temp_i_idx, temp_j_idx;
  reg [2:0] temp_k_idx;
  reg [2:0] temp_edge_idx_idx;
  reg [2:0] temp_node_idx_idx;
  reg [2:0] temp_component_idx_idx;
  reg [2:0] temp_center_idx_idx_idx;
  reg [2:0] temp_diameter_idx_idx;
  reg [2:0] temp_edge_count_idx;
  reg [2:0] temp_edge_u_idx_idx, temp_edge_v_idx_idx;
  reg [2:0] temp_add_u_idx_idx, temp_add_v_idx_idx;
  reg [2:0] temp_remove_u_idx_idx, temp_remove_v_idx_idx;
  reg [2:0] temp_best_diameter_idx_idx;
  reg [2:0] temp_component_nodes_idx_idx [7:0];
  reg [2:0] temp_component_size_idx_idx;
  reg [2:0] temp_center_idx_idx_idx;
  reg [2:0] temp_dist_idx_idx;
  reg [2:0] temp_max_idx_idx;
  reg [2:0] temp_i_idx_idx, temp_j_idx_idx;
  reg [2:0] temp_k_idx_idx;
  reg [2:0] temp_edge_idx_idx_idx;
  reg [2:0] temp_node_idx_idx_idx;
  reg [2:0] temp_component_idx_idx_idx;
  reg [2:0] temp_center_idx_idx_idx_idx;
  reg [2:0] temp_diameter_idx_idx_idx;
  reg [2:0] temp_edge_count_idx_idx;
  reg [2:0] temp_edge_u_idx_idx_idx, temp_edge_v_idx_idx_idx;
  reg [2:0] temp_add_u_idx_idx_idx, temp_add_v_idx_idx_idx;
  reg [2:0] temp_remove_u_idx_idx_idx, temp_remove_v_idx_idx_idx;
  reg [2:0] temp_best_diameter_idx_idx_idx;
  reg [2:0] temp_component_nodes_idx_idx_idx [7:0];
  reg [2:0] temp_component_size_idx_idx_idx;
  reg [2:0] temp_center_idx_idx_idx_idx;
  reg [2:0] temp_dist_idx_idx_idx;
  reg [2:0] temp_max_idx_idx_idx;
  reg [2:0] temp_i_idx_idx_idx, temp_j_idx_idx_idx;
  reg [2:0] temp_k_idx_idx_idx;
  reg [2:0] temp_edge_idx_idx_idx_idx;
  reg [2:0] temp_node_idx_idx_idx_idx;
  reg [2:0] temp_component_idx_idx_idx_idx;
  reg [2:0] temp_center_idx_idx_idx_idx;
  reg [2:0] temp_diameter_idx_idx_idx_idx;
  reg [2:0] temp_edge_count_idx_idx_idx;
  reg [2:0] temp_edge_u_idx_idx_idx_idx, temp_edge_v_idx_idx_idx_idx;
  reg [2:0] temp_add_u_idx_idx_idx_idx, temp_add_v_idx_idx_idx_idx;
  reg [2:0] temp_remove_u_idx_idx_idx_idx, temp_remove_v_idx_idx_idx_idx;
  reg [2:0] temp_best_diameter_idx_idx_idx_idx;
  reg [2:0] temp_component_nodes_idx_idx_idx_idx [7:0];
  reg [2:0] temp_component_size_idx_idx_idx_idx;
  reg [2:0] temp_center_idx_idx_idx_idx_idx;
  reg [2:0] temp_dist_idx_idx_idx_idx;
  reg [2:0] temp_max_idx_idx_idx_idx;
  reg [2:0] temp_i_idx_idx_idx_idx, temp_j_idx_idx_idx_idx;
  reg [2:0] temp_k_idx_idx_idx_idx;
  reg [2:0] temp_edge_idx_idx_idx_idx_idx;
  reg [2:0] temp_node_idx