module tuple_grouper(
  input  clk,
  input  rst_n,
  input  start,
  input  [0:3][0:2][7:0] tuples,
  input  [0:3]           valid_tuple,
  output reg [0:3][0:6][7:0] grouped,
  output reg [0:3]          valid_group,
  output reg                done
);

  typedef enum logic [2:0] {
    IDLE   = 3'd0,
    READ   = 3'd1,
    CHECK  = 3'd2,
    GROUP  = 3'd3,
    FINISH = 3'd4
  } state_t;

  state_t state, next_state;

  // Internal data latches
  reg [0:3][0:2][7:0] tuples_r;
  reg [0:3]           valid_tuple_r;

  // Group information
  reg [0:3][7:0] group_key;      // first element (key) for each group
  reg [0:3][2:0] group_len;      // current length (0-7) for each group
  reg [1:3][2:0] next_pos;       // next insertion position (per group key index 1..3)
  reg [1:3][0:6][7:0] group_concat; // concatenated chars (excluding group 0 which uses grouped directly)

  integer i;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = READ;
      end
      READ: begin
        next_state = CHECK;
      end
      CHECK: begin
        next_state = GROUP;
      end
      GROUP: begin
        next_state = FINISH;
      end
      FINISH: begin
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset outputs and internal regs
      grouped      <= '{default:'{default:8'd0}};
      valid_group  <= 4'd0;
      done         <= 1'b0;
      tuples_r     <= '{default:'{default:8'd0}};
      valid_tuple_r<= 4'd0;
      group_key    <= '{default:8'd0};
      group_len    <= '{default:3'd0};
      next_pos[1]  <= 3'd0;
      next_pos[2]  <= 3'd0;
      next_pos[3]  <= 3'd0;
      group_concat[1] <= '{default:8'd0};
      group_concat[2] <= '{default:8'd0};
      group_concat[3] <= '{default:8'd0};
    end else begin
      case (state)
        IDLE: begin
          done        <= 1'b0;
          grouped     <= '{default:'{default:8'd0}};
          valid_group <= 4'd0;
          group_key   <= '{default:8'd0};
          group_len   <= '{default:3'd0};
          next_pos[1] <= 3'd0;
          next_pos[2] <= 3'd0;
          next_pos[3] <= 3'd0;
          group_concat[1] <= '{default:8'd0};
          group_concat[2] <= '{default:8'd0};
          group_concat[3] <= '{default:8'd0};
          // Inputs are sampled in READ after start
        end

        READ: begin
          // Latch inputs
          tuples_r      <= tuples;
          valid_tuple_r <= valid_tuple;

          // Clear per-transaction group data
          grouped     <= '{default:'{default:8'd0}};
          valid_group <= 4'd0;
          done        <= 1'b0;
          group_key   <= '{default:8'd0};
          group_len   <= '{default:3'd0};
          next_pos[1] <= 3'd0;
          next_pos[2] <= 3'd0;
          next_pos[3] <= 3'd0;
          group_concat[1] <= '{default:8'd0};
          group_concat[2] <= '{default:8'd0};
          group_concat[3] <= '{default:8'd0};
        end

        CHECK: begin
          // Determine group keys based on first appearing unique first elements
          reg [7:0] k0, k1, k2, k3;
          reg       has0, has1, has2, has3;
          reg [1:0] g_cnt;

          k0 = 8'd0; k1 = 8'd0; k2 = 8'd0; k3 = 8'd0;
          has0 = 1'b0; has1 = 1'b0; has2 = 1'b0; has3 = 1'b0;
          g_cnt = 2'd0;

          for (i = 0; i < 4; i = i + 1) begin
            if (valid_tuple_r[i]) begin
              if (!has0) begin
                k0 = tuples_r[i][0];
                has0 = 1'b1;
              end else if ((tuples_r[i][0] != k0) && !has1) begin
                k1 = tuples_r[i][0];
                has1 = 1'b1;
              end else if ((tuples_r[i][0] != k0) && (tuples_r[i][0] != k1) && !has2) begin
                k2 = tuples_r[i][0];
                has2 = 1'b1;
              end else if ((tuples_r[i][0] != k0) && (tuples_r[i][0] != k1) && (tuples_r[i][0] != k2) && !has3) begin
                k3 = tuples_r[i][0];
                has3 = 1'b1;
              end
            end
          end

          // Count groups
          if (has0) g_cnt = g_cnt + 1;
          if (has1) g_cnt = g_cnt + 1;
          if (has2) g_cnt = g_cnt + 1;
          if (has3) g_cnt = g_cnt + 1;

          // Assign group keys and initialize groups
          group_key[0] <= has0 ? k0 : 8'd0;
          group_key[1] <= has1 ? k1 : 8'd0;
          group_key[2] <= has2 ? k2 : 8'd0;
          group_key[3] <= has3 ? k3 : 8'd0;

          // Initialize each group's first element (key) if present
          grouped <= '{default:'{default:8'd0}};
          valid_group <= 4'd0;
          group_len <= '{default:3'd0};
          next_pos[1] <= 3'd0;
          next_pos[2] <= 3'd0;
          next_pos[3] <= 3'd0;
          group_concat[1] <= '{default:8'd0};
          group_concat[2] <= '{default:8'd0};
          group_concat[3] <= '{default:8'd0};

          if (has0) begin
            grouped[0][0]   <= k0;
            group_len[0]    <= 3'd1;
            valid_group[0]  <= 1'b1;
          end
          if (has1) begin
            grouped[1][0]   <= k1;
            group_len[1]    <= 3'd1;
            valid_group[1]  <= 1'b1;
          end
          if (has2) begin
            grouped[2][0]   <= k2;
            group_len[2]    <= 3'd1;
            valid_group[2]  <= 1'b1;
          end
          if (has3) begin
            grouped[3][0]   <= k3;
            group_len[3]    <= 3'd1;
            valid_group[3]  <= 1'b1;
          end

          done <= 1'b0;
        end

        GROUP: begin
          integer j;
          reg [1:0] g_idx;
          reg [2:0] ins_pos;

          // Start with lengths reflecting only key chars already set in CHECK
          // For groups 1..3 we will build concatenation into group_concat then apply to grouped

          // Initialize local copies
          // (Use current group_len and group_key)

          // For each tuple, if valid, find its group by first element and append remaining chars
          for (i = 0; i < 4; i = i + 1) begin
            if (valid_tuple_r[i]) begin
              g_idx = 2'd0;

              if (tuples_r[i][0] == group_key[0]) begin
                g_idx = 2'd0;
              end else if (tuples_r[i][0] == group_key[1]) begin
                g_idx = 2'd1;
              end else if (tuples_r[i][0] == group_key[2]) begin
                g_idx = 2'd2;
              end else if (tuples_r[i][0] == group_key[3]) begin
                g_idx = 2'd3;
              end else begin
                g_idx = 2'd0; // no-op if not matched (shouldn't occur)
              end

              if (g_idx == 2'd0 && valid_group[0]) begin
                // Group 0: write directly into grouped[0]
                ins_pos = group_len[0];
                for (j = 1; j <= 2; j = j + 1) begin
                  if ((ins_pos < 3'd7) && (tuples_r[i][j] != 8'd0)) begin
                    grouped[0][ins_pos] <= tuples_r[i][j];
                    ins_pos = ins_pos + 1;
                  end
                end
                group_len[0] <= ins_pos;

              end else if (g_idx == 2'd1 && valid_group[1]) begin
                ins_pos = group_len[1];
                for (j = 1; j <= 2; j = j + 1) begin
                  if ((ins_pos < 3'd7) && (tuples_r[i][j] != 8'd0)) begin
                    group_concat[1][ins_pos] <= tuples_r[i][j];
                    ins_pos = ins_pos + 1;
                  end
                end
                group_len[1] <= ins_pos;

              end else if (g_idx == 2'd2 && valid_group[2]) begin
                ins_pos = group_len[2];
                for (j = 1; j <= 2; j = j + 1) begin
                  if ((ins_pos < 3'd7) && (tuples_r[i][j] != 8'd0)) begin
                    group_concat[2][ins_pos] <= tuples_r[i][j];
                    ins_pos = ins_pos + 1;
                  end
                end
                group_len[2] <= ins_pos;

              end else if (g_idx == 2'd3 && valid_group[3]) begin
                ins_pos = group_len[3];
                for (j = 1; j <= 2; j = j + 1) begin
                  if ((ins_pos < 3'd7) && (tuples_r[i][j] != 8'd0)) begin
                    group_concat[3][ins_pos] <= tuples_r[i][j];
                    ins_pos = ins_pos + 1;
                  end
                end
                group_len[3] <= ins_pos;
              end
            end
          end

          // Move concatenated results for groups 1..3 into grouped outputs
          for (i = 1; i < 4; i = i + 1) begin
            if (valid_group[i]) begin
              for (j = 1; j < 7; j = j + 1) begin
                if (group_concat[i][j] !== 8'dx)
                  grouped[i][j] <= group_concat[i][j];
              end
            end
          end

          done <= 1'b0;
        end

        FINISH: begin
          // Outputs stable, signal done
          done <= 1'b1;
        end

        default: begin
          // Safety
          grouped     <= '{default:'{default:8'd0}};
          valid_group <= 4'd0;
          done        <= 1'b0;
          group_key   <= '{default:8'd0};
          group_len   <= '{default:3'd0};
          next_pos[1] <= 3'd0;
          next_pos[2] <= 3'd0;
          next_pos[3] <= 3'd0;
          group_concat[1] <= '{default:8'd0};
          group_concat[2] <= '{default:8'd0};
          group_concat[3] <= '{default:8'd0};
        end
      endcase
    end
  end

endmodule