module minimum_hanoi_cost(
  input clk,
  input rst_n,
  input start,
  input [15:0] t0_r0, t0_r1, t0_r2,
  input [15:0] t1_r0, t1_r1, t1_r2,
  input [15:0] t2_r0, t2_r1, t2_r2,
  input [3:0] n,
  output reg [31:0] min_cost,
  output reg done
);

  typedef enum logic [1:0] { IDLE, INIT, PROCESS, DONE } state_t;
  state_t state, next_state;

  reg [15:0] t_reg [0:2][0:2];
  reg [31:0] dp_prev [0:2][0:2];
  reg [31:0] dp_current [0:2][0:2];
  reg [3:0] disk_count;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      min_cost <= 0;
      disk_count <= 0;
      for (int i=0; i<3; i++) begin
        for (int j=0; j<3; j++) begin
          t_reg[i][j] <= 0;
          dp_prev[i][j] <= 0;
        end
      end
    end else begin
      state <= next_state;
      case (state)
        INIT: begin
          t_reg[0][0] <= t0_r0;
          t_reg[0][1] <= t0_r1;
          t_reg[0][2] <= t0_r2;
          t_reg[1][0] <= t1_r0;
          t_reg[1][1] <= t1_r1;
          t_reg[1][2] <= t1_r2;
          t_reg[2][0] <= t2_r0;
          t_reg[2][1] <= t2_r1;
          t_reg[2][2] <= t2_r2;
          for (int i=0; i<3; i++) begin
            for (int j=0; j<3; j++) begin
              dp_prev[i][j] <= 0;
            end
          end
          disk_count <= 0;
          done <= 0;
        end
        PROCESS: begin
          if (disk_count < n) begin
            disk_count <= disk_count + 1;
            for (int i=0; i<3; i++) begin
              for (int j=0; j<3; j++) begin
                dp_prev[i][j] <= dp_current[i][j];
              end
            end
          end
          if (disk_count == n) begin
            min_cost <= dp_prev[0][2];
            done <= 1;
          end else done <= 0;
        end
        DONE: done <= 1;
        default: done <= 0;
      endcase
    end
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE: if (start) next_state = INIT;
      INIT: next_state = PROCESS;
      PROCESS: begin
        if (disk_count == n) next_state = DONE;
        else if (disk_count < n) next_state = PROCESS;
      end
      DONE: if (start) next_state = INIT;
    endcase
  end

  always_comb begin
    for (int i=0; i<3; i++) begin
      for (int j=0; j<3; j++) begin
        dp_current[i][j] = 32\'d0;
      end
    end
    if (state == PROCESS && disk_count < n) begin
      for (int frm=0; frm<3; frm++) begin
        for (int to=0; to<3; to++) begin
          if (frm != to) begin
            automatic int other = 3 - frm - to;
            automatic logic [31:0] cost_option1, cost_option2;
            cost_option1 = dp_prev[frm][other] + t_reg[frm][to] + dp_prev[other][to];
            cost_option2 = dp_prev[frm][to] + t_reg[frm][other] + dp_prev[to][frm] + t_reg[other][to] + dp_prev[frm][to];
            dp_current[frm][to] = (cost_option1 < cost_option2) ? cost_option1 : cost_option2;
          end
        end
      end
    end
  end

endmodule