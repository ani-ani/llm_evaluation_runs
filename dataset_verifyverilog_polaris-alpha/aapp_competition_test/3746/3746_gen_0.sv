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

  // State encoding
  localparam IDLE    = 2'b00;
  localparam INIT    = 2'b01;
  localparam PROCESS = 2'b10;
  localparam DONE    = 2'b11;

  reg [1:0] state, next_state;

  // Latched inputs
  reg [15:0] t [0:2][0:2];
  reg [3:0] n_reg;

  // dp[i][frm][to]: i=0..4, frm=0..2, to=0..2
  reg [31:0] dp [0:4][0:2][0:2];

  reg [2:0] disk_idx; // 0..4

  integer i, f, to;

  // Combinational next_state
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = INIT;
      end
      INIT: begin
        next_state = PROCESS;
      end
      PROCESS: begin
        if (disk_idx == n_reg)
          next_state = DONE;
        else
          next_state = PROCESS;
      end
      DONE: begin
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      done      <= 1'b0;
      min_cost  <= 32'd0;
      n_reg     <= 4'd0;
      disk_idx  <= 3'd0;
      // Clear t and dp
      for (i = 0; i <= 2; i = i + 1) begin
        t[i][0] <= 16'd0;
        t[i][1] <= 16'd0;
        t[i][2] <= 16'd0;
      end
      for (i = 0; i <= 4; i = i + 1) begin
        for (f = 0; f <= 2; f = f + 1) begin
          dp[i][f][0] <= 32'd0;
          dp[i][f][1] <= 32'd0;
          dp[i][f][2] <= 32'd0;
        end
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done     <= 1'b0;
          min_cost <= 32'd0;
          if (start) begin
            // Latch inputs in INIT via next_state
          end
        end

        INIT: begin
          // Latch cost matrix
          t[0][0] <= t0_r0; t[0][1] <= t0_r1; t[0][2] <= t0_r2;
          t[1][0] <= t1_r0; t[1][1] <= t1_r1; t[1][2] <= t1_r2;
          t[2][0] <= t2_r0; t[2][1] <= t2_r1; t[2][2] <= t2_r2;

          // Latch n (cap at 4 just in case)
          if (n > 4'd4)
            n_reg <= 4'd4;
          else
            n_reg <= n;

          // Initialize base case dp[0]
          for (f = 0; f <= 2; f = f + 1) begin
            for (to = 0; to <= 2; to = to + 1) begin
              if (f == to)
                dp[0][f][to] <= 32'd0;
              else
                dp[0][f][to] <= {16'd0, t[f][to]};
            end
          end

          disk_idx <= 3'd1; // first disk count to process
          done     <= 1'b0;
        end

        PROCESS: begin
          if (disk_idx <= n_reg) begin
            // Compute dp[disk_idx] for all frm,to
            for (f = 0; f <= 2; f = f + 1) begin
              for (to = 0; to <= 2; to = to + 1) begin
                if (f == to) begin
                  dp[disk_idx][f][to] <= 32'd0;
                end else begin
                  // other = 3 - f - to
                  reg [1:0] other;
                  reg [31:0] cost1;
                  reg [31:0] cost2;

                  other = 3 - f - to;

                  // cost_option1 = dp[i-1][f][other] + t[f][to] + dp[i-1][other][to]
                  cost1 = dp[disk_idx-1][f][other]
                          + {16'd0, t[f][to]}
                          + dp[disk_idx-1][other][to];

                  // cost_option2 = dp[i-1][f][to] + t[f][other] + dp[i-1][to][f]
                  //               + t[other][to] + dp[i-1][f][to]
                  cost2 = dp[disk_idx-1][f][to]
                          + {16'd0, t[f][other]}
                          + dp[disk_idx-1][to][f]
                          + {16'd0, t[other][to]}
                          + dp[disk_idx-1][f][to];

                  if (cost1 <= cost2)
                    dp[disk_idx][f][to] <= cost1;
                  else
                    dp[disk_idx][f][to] <= cost2;
                end
              end
            end

            disk_idx <= disk_idx + 3'd1;
          end
        end

        DONE: begin
          done     <= 1'b1;
          min_cost <= dp[n_reg][0][2];
        end

        default: begin
        end
      endcase
    end
  end

endmodule