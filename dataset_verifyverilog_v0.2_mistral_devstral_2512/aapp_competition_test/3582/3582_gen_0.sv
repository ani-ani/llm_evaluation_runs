module gaggle_mentor (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [7:0][7:0] current_mentor,
  output reg [7:0] new_mentor,
  output reg [2:0] employee_idx,
  output reg done
);

  // States
  typedef enum logic [1:0] {
    IDLE,
    FIND_BEST_CYCLE,
    OUTPUT_RESULTS,
    DONE
  } state_t;

  state_t state;
  reg [7:0] best_mentor [0:7];
  reg [7:0] current_mentor_reg [0:7];
  reg [7:0] candidate_mentor [0:7];
  reg [7:0] best_score;
  reg [7:0] current_score;
  reg [2:0] cycle_counter;
  reg [2:0] employee_counter;
  reg [2:0] n_reg;
  reg [2:0] n_minus_one;
  reg [2:0] i, j, k;
  reg [7:0] temp_mentor [0:7];
  reg [7:0] visited;
  reg [7:0] in_cycle;
  reg [7:0] cycle_start;
  reg [7:0] cycle_length;
  reg [7:0] cycle_valid;
  reg [7:0] score;
  reg [7:0] temp_score;
  reg [7:0] temp_best_score;
  reg [7:0] temp_current_score;
  reg [7:0] temp_employee_counter
