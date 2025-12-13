module stack_operations(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        cmd_valid,
  input  logic [1:0]  op_type,      // 0=push('a'),1=pop('b'),2=count('c')
  input  logic [3:0]  v,            // source stack index
  input  logic [3:0]  w,            // target stack index for 'c'
  output logic [4:0]  result,       // popped value or common count
  output logic        result_valid,
  output logic        done
);

  // 16 stacks, each up to 16 elements, 4-bit values
  // stack_mem[stack][index]
  logic [3:0] stack_mem [0:15][0:15];
  logic [4:0] sp        [0:15];       // stack pointer = current depth (0-16)

  logic [3:0] step_cnt;               // 0..15, operations at steps 1..15

  // pipeline regs for result
  logic [4:0] result_r;
  logic       result_valid_r;

  // presence vectors for 'c' operation
  logic [15:0] pres_src;
  logic [15:0] pres_tgt;
  logic [15:0] common_mask;
  logic [4:0]  common_count;

  // combinational presence vector/gen popcount for active cmd
  integer i;
  always_comb begin
    pres_src     = 16'b0;
    pres_tgt     = 16'b0;
    common_mask  = 16'b0;
    common_count = 5'd0;

    if (cmd_valid && (op_type == 2'd2) && (step_cnt != 4'd0) && (step_cnt <= 4'd15)) begin
      // New stack index i = step_cnt
      // Build presence for stack i (source) using its current contents
      // and for stack w.
      // Use element value as bit index.
      for (i = 0; i < 16; i = i + 1) begin
        if (i < sp[step_cnt]) begin
          pres_src[ stack_mem[step_cnt][i] ] = 1'b1;
        end
        if (i < sp[w]) begin
          pres_tgt[ stack_mem[w][i] ] = 1'b1;
        end
      end
      common_mask = pres_src & pres_tgt;

      // popcount of 16-bit common_mask
      common_count = common_mask[0]  + common_mask[1]  +
                     common_mask[2]  + common_mask[3]  +
                     common_mask[4]  + common_mask[5]  +
                     common_mask[6]  + common_mask[7]  +
                     common_mask[8]  + common_mask[9]  +
                     common_mask[10] + common_mask[11] +
                     common_mask[12] + common_mask[13] +
                     common_mask[14] + common_mask[15];
    end
  end

  // sequential logic
  integer j;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Initialize all stacks as empty; only requirement explicitly: stack 0 empty
      for (j = 0; j < 16; j = j + 1) begin
        sp[j] <= 5'd0;
      end
      step_cnt       <= 4'd0;
      result_r       <= 5'd0;
      result_valid_r <= 1'b0;
      done           <= 1'b0;
    end else begin
      // default: no result this cycle
      result_valid_r <= 1'b0;

      if (cmd_valid && (step_cnt < 4'd15)) begin
        // compute new stack index i for this step
        logic [3:0] new_idx;
        new_idx = step_cnt + 4'd1;

        // 1) copy stack v to new stack new_idx
        sp[new_idx] <= sp[v];
        for (j = 0; j < 16; j = j + 1) begin
          stack_mem[new_idx][j] <= stack_mem[v][j];
        end

        // 2) perform operation on new stack
        case (op_type)
          2'd0: begin // push: push step number (i = new_idx)
            if (sp[v] < 5'd16) begin
              stack_mem[new_idx][ sp[v] ] <= {1'b0, new_idx};
              sp[new_idx]                <= sp[v] + 5'd1;
            end
          end

          2'd1: begin // pop
            if (sp[v] != 5'd0) begin
              // pop from copied stack (from top-1)
              result_r       <= {1'b0, stack_mem[new_idx][ sp[v] - 5'd1 ]};
              result_valid_r <= 1'b1;
              sp[new_idx]    <= sp[v] - 5'd1;
            end else begin
              result_r       <= 5'd0;
              result_valid_r <= 1'b1;
              sp[new_idx]    <= 5'd0;
            end
          end

          2'd2: begin // count common distinct elements between new_idx and w
            // presence vectors and common_count computed combinationally
            result_r       <= common_count;
            result_valid_r <= 1'b1;
          end

          default: begin
            // no-op
          end
        endcase

        // advance step counter after processing this command
        step_cnt <= new_idx;

        // done after step 15 completes
        if (new_idx == 4'd15) begin
          done <= 1'b1;
        end
      end
    end
  end

  assign result       = result_r;
  assign result_valid = result_valid_r;

endmodule