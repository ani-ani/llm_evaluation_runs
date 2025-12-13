module ncpc_partition(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [2:0] a,
  input [2:0] b,
  input [5:0] year,
  input valid_pair,
  output reg [5:0] Y,
  output reg impossible,
  output reg done
);

  // Internal storage for pair years: encode (i<j) as idx = i*6 + j, 0-based
  // Use 7-bit: MSB=1 means "has constraint", lower 6 bits = year (0-60)
  reg [6:0] edge [0:35];

  // FSM states
  typedef enum logic [2:0] {
    S_IDLE      = 3'd0,
    S_LOAD      = 3'd1,
    S_PREP      = 3'd2,
    S_CHECK_Y   = 3'd3,
    S_DONE      = 3'd4
  } state_t;

  state_t state, next_state;

  // Registers for control
  reg [5:0] curY;              // current Y candidate
  reg [5:0] bestY;             // best found Y
  reg       found_solution;    // flag that some Y is valid

  reg [5:0] part_mask;         // subset of participants; bit i -> group A
  reg       valid_for_Y;       // current Y still valid while scanning subsets
  reg       subset_done;       // flag indicating all subsets checked

  reg [2:0] nn;                // latched n

  // helpers
  integer i, j;
  integer idx;

  // compute floor(2n/3) for n in [0..6]
  function automatic [2:0] max_group_size(input [2:0] n_local);
    begin
      case (n_local)
        3'd0: max_group_size = 3'd0;
        3'd1: max_group_size = 3'd0; // not used
        3'd2: max_group_size = 3'd1; // not used
        3'd3: max_group_size = 3'd2;
        3'd4: max_group_size = 3'd2;
        3'd5: max_group_size = 3'd3;
        3'd6: max_group_size = 3'd4;
        default: max_group_size = 3'd4;
      endcase
    end
  endfunction

  // population count for up to 6 bits
  function automatic [2:0] popcount6(input [5:0] v);
    integer k;
    reg [2:0] c;
    begin
      c = 3'd0;
      for (k = 0; k < 6; k = k + 1)
        if (v[k]) c = c + 3'd1;
      popcount6 = c;
    end
  endfunction

  // map pair (1..6,1..6) to index (0..35), only store if i<j
  function automatic integer pair_index(input [2:0] ia, input [2:0] ib);
    integer i0, j0;
    begin
      if (ia < ib) begin
        i0 = ia - 1;
        j0 = ib - 1;
      end else begin
        i0 = ib - 1;
        j0 = ia - 1;
      end
      pair_index = i0*6 + j0;
    end
  endfunction

  // check if current partition (part_mask) is valid for year curY
  function automatic bit partition_ok(
      input [5:0] mask,
      input [5:0] Y_local,
      input [2:0] n_local,
      input [6:0] edge_arr [0:35]
  );
    integer pi, pj;
    integer pidx;
    reg [2:0] cntA, cntB;
    reg [2:0] limit;
    reg inA_i, inA_j;
    reg [5:0] yr;
    begin
      // only participants 0..n_local-1 are relevant
      cntA = popcount6(mask & ((6'b000001 << n_local) - 1));
      cntB = n_local - cntA;
      limit = max_group_size(n_local);
      if (cntA > limit || cntB > limit) begin
        partition_ok = 1'b0;
      end else begin
        partition_ok = 1'b1;
        for (pi = 0; pi < 6; pi = pi + 1) begin
          if (pi < n_local) begin
            for (pj = pi+1; pj < 6; pj = pj + 1) begin
              if (pj < n_local) begin
                pidx = pi*6 + pj;
                if (edge_arr[pidx][6]) begin
                  inA_i = mask[pi];
                  inA_j = mask[pj];
                  yr    = edge_arr[pidx][5:0];
                  if (inA_i && inA_j) begin
                    if (!(yr < Y_local)) begin
                      partition_ok = 1'b0;
                      disable inner_loops;
                    end
                  end else if (!inA_i && !inA_j) begin
                    if (!(yr >= Y_local)) begin
                      partition_ok = 1'b0;
                      disable inner_loops;
                    end
                  end
                end
              end
            end
          end
        end
      end
      inner_loops: ;
    end
  endfunction

  // Sequential FSM
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= S_IDLE;
      Y               <= 6'd0;
      impossible      <= 1'b0;
      done            <= 1'b0;
      curY            <= 6'd0;
      bestY           <= 6'd0;
      found_solution  <= 1'b0;
      part_mask       <= 6'd0;
      valid_for_Y     <= 1'b0;
      subset_done     <= 1'b0;
      nn              <= 3'd0;
      for (i = 0; i < 36; i = i + 1) begin
        edge[i] <= 7'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done           <= 1'b0;
          impossible     <= 1'b0;
          found_solution <= 1'b0;
          if (start) begin
            // clear edges
            for (i = 0; i < 36; i = i + 1) begin
              edge[i] <= 7'd0;
            end
            nn <= n;
          end
        end

        S_LOAD: begin
          // accept pairs while valid_pair is high
          if (valid_pair) begin
            if (a != b) begin
              idx = pair_index(a, b);
              edge[idx] <= {1'b1, year};
            end
          end
        end

        S_PREP: begin
          // initialize search
          curY           <= 6'd0;   // corresponds to 1948
          bestY          <= 6'd0;
          found_solution <= 1'b0;
          part_mask      <= 6'd0;
          valid_for_Y    <= 1'b0;
          subset_done    <= 1'b0;
        end

        S_CHECK_Y: begin
          if (!subset_done) begin
            // evaluating subsets for current Y
            if (!valid_for_Y) begin
              // check current subset
              if (partition_ok(part_mask, curY, nn, edge)) begin
                valid_for_Y <= 1'b1;
              end
              // advance subset
              if (part_mask == ((6'b000001 << nn) - 1)) begin
                subset_done <= 1'b1;
              end else begin
                part_mask <= part_mask + 6'd1;
              end
            end else begin
              // already found valid partition for this Y
              found_solution <= 1'b1;
              if (!found_solution) begin
                bestY <= curY;
              end else if (curY < bestY) begin
                bestY <= curY;
              end
              // move to next Y
              if (curY == 6'd60) begin
                subset_done <= 1'b1; // signal end of all Y
              end else begin
                curY        <= curY + 6'd1;
                part_mask   <= 6'd0;
                valid_for_Y <= 1'b0;
                subset_done <= 1'b0;
              end
            end
          end else begin
            // subset_done asserted due to finishing subsets without valid partition
            if (!valid_for_Y) begin
              // no partition for this Y; move to next Y or finish
              if (curY == 6'd60) begin
                // done all Y
              end else begin
                curY        <= curY + 6'd1;
                part_mask   <= 6'd0;
                valid_for_Y <= 1'b0;
                subset_done <= 1'b0;
              end
            end
          end
        end

        S_DONE: begin
          done <= 1'b1;
        end

        default: ;
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start) next_state = S_LOAD;
      end

      S_LOAD: begin
        // Transition when start deasserted (end of input), begin computation
        if (!start) next_state = S_PREP;
      end

      S_PREP: begin
        next_state = S_CHECK_Y;
      end

      S_CHECK_Y: begin
        // completion condition: tried all Y (0..60) and either
        // found solution or confirmed impossible
        if ( (curY == 6'd60) && subset_done && (!valid_for_Y) ) begin
          // no valid partition for last Y
          next_state = S_DONE;
        end else if ((curY == 6'd60) && valid_for_Y) begin
          // last Y had valid partition
          next_state = S_DONE;
        end else begin
          next_state = S_CHECK_Y;
        end
      end

      S_DONE: begin
        // stay until reset; could optionally go to IDLE on new start
        next_state = S_DONE;
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Output logic in DONE state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      Y          <= 6'd0;
      impossible <= 1'b0;
    end else begin
      if (state == S_DONE && !done) begin
        // determine if any valid Y found
        // found_solution is latched when a valid partition encountered
        if (found_solution || valid_for_Y) begin
          Y          <= bestY;
          impossible <= 1'b0;
        end else begin
          Y          <= 6'd0;
          impossible <= 1'b1;
        end
      end
    end
  end

endmodule