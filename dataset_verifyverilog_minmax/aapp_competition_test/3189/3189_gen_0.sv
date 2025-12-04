module wiring_possibilities(
  input reg clk,
  input reg rst_n,
  input reg start,
  input reg [1:0] m,
  input reg [3:0] photo1_sw,
  input reg [3:0] photo1_lgt,
  input reg [3:0] photo2_sw,
  input reg [3:0] photo2_lgt,
  output reg [19:0] result,
  output reg done
);

  // Internal state and data
  localparam MOD = 20'd1000003;
  localparam IDLE = 2'b00;
  localparam CALC = 2'b01;
  localparam DONE = 2'b10;

  logic [1:0] state;
  logic [4:0] perm_idx;          // 0..23
  logic [1:0] step;              // step within a permutation
  logic valid;                    // current perm is still valid
  logic [19:0] count;             // number of valid perms
  logic [1:0] m_reg;              // latched number of photos

  // ROM holding all 24 permutations of 4 switches to 4 lights
  // perm_map[i][j] gives the light index (0..3) that switch j maps to for permutation i
  logic [1:0] perm_map[0:23][0:3];

  initial begin
    perm_map[0] = '{2'd0,2'd1,2'd2,2'd3};
    perm_map[1] = '{2'd0,2'd1,2'd3,2'd2};
    perm_map[2] = '{2'd0,2'd2,2'd1,2'd3};
    perm_map[3] = '{2'd0,2'd2,2'd3,2'd1};
    perm_map[4] = '{2'd0,2'd3,2'd1,2'd2};
    perm_map[5] = '{2'd0,2'd3,2'd2,2'd1};
    perm_map[6] = '{2'd1,2'd0,2'd2,2'd3};
    perm_map[7] = '{2'd1,2'd0,2'd3,2'd2};
    perm_map[8] = '{2'd1,2'd2,2'd0,2'd3};
    perm_map[9] = '{2'd1,2'd2,2'd3,2'd0};
    perm_map[10] = '{2'd1,2'd3,2'd0,2'd2};
    perm_map[11] = '{2'd1,2'd3,2'd2,2'd0};
    perm_map[12] = '{2'd2,2'd0,2'd1,2'd3};
    perm_map[13] = '{2'd2,2'd0,2'd3,2'd1};
    perm_map[14] = '{2'd2,2'd1,2'd0,2'd3};
    perm_map[15] = '{2'd2,2'd1,2'd3,2'd0};
    perm_map[16] = '{2'd2,2'd3,2'd0,2'd1};
    perm_map[17] = '{2'd2,2'd3,2'd1,2'd0};
    perm_map[18] = '{2'd3,2'd0,2'd1,2'd2};
    perm_map[19] = '{2'd3,2'd0,2'd2,2'd1};
    perm_map[20] = '{2'd3,2'd1,2'd0,2'd2};
    perm_map[21] = '{2'd3,2'd1,2'd2,2'd0};
    perm_map[22] = '{2'd3,2'd2,2'd0,2'd1};
    perm_map[23] = '{2'd3,2'd2,2'd1,2'd0};
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 0;
      done <= 1'b0;
      perm_idx <= 0;
      step <= 0;
      valid <= 1'b1;
      count <= 0;
      m_reg <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            state <= CALC;
            perm_idx <= 5'd0;
            step <= 2'd0;
            valid <= 1'b1;
            count <= 20'd0;
            m_reg <= m;
          end
        end
        CALC: begin
          // Choose the appropriate switch and light vectors for this step
          logic [3:0] sw;
          logic [3:0] lgt;
          if (m_reg != 2'd0 && step < m_reg) begin
            case (step)
              2'd0: begin sw = photo1_sw; lgt = photo1_lgt; end
              2'd1: begin sw = photo2_sw; lgt = photo2_lgt; end
              default: begin sw = 4'd0; lgt = 4'd0; end
            endcase
            // Verify mapping for all 4 switches
            logic [1:0] l_idx;
            for (int i = 0; i < 4; i++) begin
              l_idx = perm_map[perm_idx][i];
              if (sw[i] !== lgt[l_idx]) begin
                valid <= 1'b0;
              end
            end
          end

          // Determine if this is the last step for the current permutation
          logic [1:0] lastStep;
          lastStep = (m_reg == 2'd0) ? 2'd0 : (m_reg == 2'd1 ? 2'd0 : 2'd1);
          if (step == lastStep) begin
            // Finalize this permutation
            if (valid) begin
              count <= count + 1;
            end
            if (perm_idx == 5'd23) begin
              // All permutations processed
              result <= count % MOD;
              state <= DONE;
            end else begin
              perm_idx <= perm_idx + 1'b1;
              step <= 2'd0;
              valid <= 1'b1;
            end
          end else begin
            step <= step + 1'b1;
          end
        end
        DONE: begin
          done <= 1'b1;
          state <= IDLE;
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule