module minimal_convex_hull_vertices(
  input clk,
  input rst_n,
  input start,
  input [15:0] vx[0:7],
  input [15:0] vy[0:7],n  input [2:0] vertex_count,
  input [15:0] px[0:3],
  input [15:0] py[0:3],
  input [1:0] point_count,
  output reg [2:0] min_vertices,
  output reg done
);

  typedef enum logic [2:0] {IDLE, CHECK_SIZE, CHECK_COMB, CHECK_POINT, FOUND, DONE_ST} state_t;
  state_t state, next_state;

  reg [2:0] k;
  reg [7:0] mask;
  reg [15:0] sel_vx[0:7];
  reg [15:0] sel_vy[0:7];
  reg [2:0] sel_cnt;
  reg [1:0] p_idx;
  reg [2:0] e_idx;
  reg [1:0] exp_sign;
  reg p_valid;
  reg all_inside;
  reg [1:0] pcnt;

  wire [3:0] pc;
  assign pc = mask[0] + mask[1] + mask[2] + mask[3] + mask[4] + mask[5] + mask[6] + mask[7];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      min_vertices <= 0;
      k <= 3;
      mask <= 1;
      sel_cnt <= 0;
      p_idx <= 0;
      e_idx <= 0;
      exp_sign <= 0;
      p_valid <= 0;
      all_inside <= 0;
    end else begin
      state <= next_state;

      case(state)
        IDLE: begin
          if (start) begin
            k <= 3;
            mask <= 1;
            done <= 0;
          end
        end

        CHECK_SIZE: begin
          if (mask[vertex_count] == 0 && pc == k) begin
            sel_cnt <= 0;
            for (int i=0; i<8