module tuple_grouper (
  input clk,
  input rst_n,
  input start,
  input [0:3][0:2][7:0] tuples,
  input [0:3] valid_tuple,
  output reg [0:3][0:6][7:0] grouped,
  output reg [0:3] valid_group,
  output reg done
);

  // Internal state
  typedef enum logic [2:0] { IDLE=3'd0, READ=3'd1, CHECK=3'd2, GROUP=3'd3, FINISH=3'd4 } state_t;
  state_t state, next_state;

  // Capture inputs on READ
  logic [0:3][0:2][7:0] tuples_r;
  logic [0:3] valid_mask_r;

  // Group build signals
  logic [3:0][7:0] group_first;       // First char of each group (7:0 is ASCII, others ignored)
  logic [3:0] group_exists;           // Whether a group is used
  logic [3:0][5:0] group_len;         // Current used length (max 6 per group)
  logic [0:3][0:5][7:0] group_tail;   // Tail bytes for each group (up to 6 chars)

  // Sequential logic (clock and reset)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      grouped <= '{default: '0};
      valid_group <= 4'b0000;
      // Clear internal working storage as well
      tuples_r <= '{default: '0};
      valid_mask_r <= 4'b0000;
      group_first <= 8'b0;
      group_exists <= 4'b0;
      group_len <= 6'b0;
      group_tail <= '{default: '0};
    end else begin
      state <= next_state;

      case (next_state)
        IDLE: begin
          done <= 1'b0;
          grouped <= '{default: '0};
          valid_group <= 4'b0000;
          // Clear working state
          tuples_r <= '{default: '0};
          valid_mask_r <= 4'b0000;
          group_first <= 8'b0;
          group_exists <= 4'b0;
          group_len <= 6'b0;
          group_tail <= '{default: '0};
        end

        READ: begin
          // Capture inputs and reset working group state
          tuples_r <= tuples;
          valid_mask_r <= valid_tuple;
          group_first <= 8'b0;
          group_exists <= 4'b0;
          group_len <= 6'b0;
          group_tail <= '{default: '0};
          done <= 1'b0;
        end

        CHECK: begin
          // Determine groups based on first elements (order of appearance)
          // Start from a cleared group state
          group_first <= 8'b0;
          group_exists <= 4'b0;
          group_len <= 6'b0;
          group_tail <= '{default: '0};

          for (int i = 0; i < 4; i++) begin
            if (valid_mask_r[i]) begin
              logic found;
              logic [1:0] gid; // group id 0..3
              found = 1'b0;
              gid = 2'd0;
              for (int g = 0; g < 4; g++) begin
                if (group_exists[g] && (group_first[g] == tuples_r[i][0])) begin
                  found = 1'b1;
                  gid = g[1:0];
                end
              end
              if (!found) begin
                // find first free group slot
                for (int g = 0; g < 4; g++) begin
                  if (!group_exists[g]) begin
                    group_exists[g] <= 1'b1;
                    group_first[g] <= tuples_r[i][0];
                    group_len[g] <= 6'b0; // length counts only tail (first char not stored here)
                    gid = g[1:0];
                    break;
                  end
                end
              end
              // Save tail len for this tuple in temp (not used to build, but we could)
              // No structural action here; handled in GROUP state.
            end
          end
        end

        GROUP: begin
          // Build groups: tail bytes per valid tuple go to matching group
          // Ensure groups and first elements remain as set in CHECK
          // Clear outputs before fill
          grouped <= '{default: '0};
          valid_group <= 4'b0000;

          for (int i = 0; i < 4; i++) begin
            if (valid_mask_r[i]) begin
              // Find matching group (reuse logic from CHECK state)
              logic [1:0] gid;
              logic found;
              found = 1'b0;
              for (int g = 0; g < 4; g++) begin
                if (group_exists[g] && (group_first[g] == tuples_r[i][0])) begin
                  gid = g[1:0];
                  found = 1'b1;
                  break;
                end
              end
              if (found) begin
                if (group_len[gid] < 6) begin
                  // Append element 1 at index 0, then 2 at index 1
                  for (int e = 1; e < 3; e++) begin
                    if (e == 1) begin
                      if (group_len[gid] < 6) begin
                        group_tail[gid][group_len[gid]] <= tuples_r[i][e];
                        group_len[gid] <= group_len[gid] + 1;
                      end
                    end else if (e == 2) begin
                      if (group_len[gid] < 6) begin
                        group_tail[gid][group_len[gid]] <= tuples_r[i][e];
                        group_len[gid] <= group_len[gid] + 1;
                      end
                    end
                  end
                end
              end
            end
          end
        end

        FINISH: begin
          // Compose final grouped outputs from group_first + group_tail
          grouped <= '{default: '0};
          valid_group <= 4'b0000;
          for (int g = 0; g < 4; g++) begin
            if (group_exists[g]) begin
              logic [5:0] len;
              len = group_len[g]; // number of tail chars (0..6)
              // Place first char
              grouped[g][0] <= group_first[g];
              // Place tail chars at 1..len
              for (int k = 0; k < 6; k++) begin
                if (k < len) begin
                  grouped[g][k+1] <= group_tail[g][k];
                end
              end
              // valid_group set for used groups only
              valid_group[g] <= 1'b1;
            end else begin
              valid_group[g] <= 1'b0;
            end
          end
          done <= 1'b1;
        end

        default: begin
          // Safety
          done <= 1'b0;
          grouped <= '{default: '0};
          valid_group <= 4'b0000;
        end
      endcase
    end
  end

  // Combinational next-state logic
  always_comb begin
    case (state)
      IDLE:  next_state = (start ? READ : IDLE);
      READ:  next_state = CHECK;
      CHECK: next_state = GROUP;
      GROUP: next_state = FINISH;
      FINISH: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

endmodule