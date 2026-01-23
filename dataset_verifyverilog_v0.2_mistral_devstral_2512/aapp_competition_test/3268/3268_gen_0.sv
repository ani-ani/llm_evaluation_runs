module bird_label_solver (
  input clk,
  input rst_n,
  input start,
  input config_mode,
  input [5:0] parent,
  input [1:0] v_type,
  input [1:0] v_subtype,
  input [39:0] v_label,
  output reg result_valid,
  output reg [3:0] change_count,
  output reg [5:0] change_v_idx,
  output reg [39:0] new_label
);

  // Tree storage
  reg [5:0] parent_arr [0:15];
  reg [1:0] type_arr [0:15];
  reg [1:0] subtype_arr [0:15];
  reg [39:0] label_arr [0:15];
  reg [15:0] controlled_area [0:15];
  reg [15:0] controlled_area_giant [0:15];

  // State machine
  parameter IDLE = 0, CONFIG = 1, COMPUTE = 2, DONE = 3;
  reg [1:0] state = IDLE;
  reg [9:0] counter = 0;
  reg [5:0] node_idx = 0;
  reg [5:0] bird_idx = 0;
  reg [5:0] berry_idx = 0;
  reg [5:0] conflict_idx = 0;
  reg [5:0] owner_idx = 0;
  reg [5:0] new_label_idx = 0;
  reg [3:0] temp_change_count = 0;
  reg [5:0] temp_change_v_idx = 0;
  reg [39:0] temp_new_label = 0;
  reg [15:0] temp_area = 0;
  reg [15:0] temp_area_giant = 0;
  reg [15:0] temp_subtree = 0;
  reg [15:0] temp_subtree_giant = 0;
  reg [15:0] temp_mask = 0;
  reg [15:0] temp_mask_giant = 0;
  reg [15:0] temp_berry_area = 0;
  reg [15:0] temp_berry_area_giant = 0;
  reg [15:0] temp_owner_area = 0;
  reg [15:0] temp_owner_area_giant = 0;
  reg [15:0] temp_owner_mask = 0;
  reg [15:0] temp_owner_mask_giant = 0;
  reg [15:0] temp_owner_subtree = 0;
  reg [15:0] temp_owner_subtree_giant = 0;
  reg [15:0] temp_owner_subtree_mask = 0;
  reg [15:0] temp_owner_subtree_mask_giant = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_giant_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp_temp = 0;
  reg [15:0] temp_owner_subtree_mask