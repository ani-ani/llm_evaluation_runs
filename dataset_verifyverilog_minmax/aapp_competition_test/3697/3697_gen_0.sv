module election_predictor(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [2:0] k,
  input [7:0] m_remaining,
  input [2:0] candidate_id,
  input [7:0] current_votes,
  input [7:0] last_vote_time,
  input load_data,
  output reg [1:0] result, // 1=guaranteed, 2=possible, 3=no chance
  output reg done
);

  // Constants
  localparam C = 8;                 // Max candidates
  localparam W = 8;                 // Vote/time width
  localparam ST_IDLE = 2'b00;
  localparam ST_WORK = 2'b01;
  localparam ST_DONE = 2'b10;

  // Candidate storage
  reg [7:0] votes_r   [0:C-1];
  reg [7:0] times_r   [0:C-1];

  // Sorting network registers (current candidates)
  reg [7:0] s_votes_r   [0:C-1];
  reg [7:0] s_times_r   [0:C-1];
  reg [2:0] s_id_r      [0:C-1];

  // Result vector: 2 bits per candidate, lower indices first
  reg [15:0] result_vec; // bit [1:0] -> candidate 0, bit [3:2] -> candidate 1, etc.

  // State machine
  reg [1:0] state;
  reg [5:0] cycle;      // up to 64 cycles
  reg [2:0] read_ptr;   // output pointer for sequential results

  // Internal signals
  wire [7:0] rank0_v, rank1_v, rank2_v, rank3_v, rank4_v, rank5_v, rank6_v, rank7_v;
  wire [7:0] rank0_t, rank1_t, rank2_t, rank3_t, rank4_t, rank5_t, rank6_t, rank7_t;
  wire [2:0] rank0_i, rank1_i, rank2_i, rank3_i, rank4_i, rank5_i, rank6_i, rank7_i;
  wire [7:0] kth_votes, kth_minus1_votes;
  wire [7:0] kth_votes_plus1;
  wire [7:0] kth_votes_minus1;
  wire k_valid;
  wire kth_is_tie;

  // Assign outputs from sorted stage (combinationally available after sorting)
  assign rank0_v = s_votes_r[0];  assign rank0_t = s_times_r[0];  assign rank0_i = s_id_r[0];
  assign rank1_v = s_votes_r[1];  assign rank1_t = s_times_r[1];  assign rank1_i = s_id_r[1];
  assign rank2_v = s_votes_r[2];  assign rank2_t = s_times_r[2];  assign rank2_i = s_id_r[2];
  assign rank3_v = s_votes_r[3];  assign rank3_t = s_times_r[3];  assign rank3_i = s_id_r[3];
  assign rank4_v = s_votes_r[4];  assign rank4_t = s_times_r[4];  assign rank4_i = s_id_r[4];
  assign rank5_v = s_votes_r[5];  assign rank5_t = s_times_r[5];  assign rank5_i = s_id_r[5];
  assign rank6_v = s_votes_r[6];  assign rank6_t = s_times_r[6];  assign rank6_i = s_id_r[6];
  assign rank7_v = s_votes_r[7];  assign rank7_t = s_times_r[7];  assign rank7_i = s_id_r[7];

  // kth vote and neighbors (with tie handling)
  assign k_valid = (k >= 1) && (k <= C);
  assign kth_votes = (k == 1) ? rank0_v :
                     (k == 2) ? rank1_v :
                     (k == 3) ? rank2_v :
                     (k == 4) ? rank3_v :
                     (k == 5) ? rank4_v :
                     (k == 6) ? rank5_v :
                     (k == 7) ? rank6_v :
                                rank7_v;

  // For tie handling: identify if there are multiple candidates with exactly kth_votes within the top-k band
  // If ties exist exactly at the kth position, then (kth - 1) rank still equals kth votes.
  wire [7:0] kth_minus1_v = (k == 1) ? 8'd0 :
                             (k == 2) ? rank0_v :
                             (k == 3) ? rank1_v :
                             (k == 4) ? rank2_v :
                             (k == 5) ? rank3_v :
                             (k == 6) ? rank4_v :
                             (k == 7) ? rank5_v :
                                        rank6_v;
  assign kth_minus1_votes = kth_minus1_v;
  assign kth_is_tie = kth_minus1_votes == kth_votes;
  assign kth_votes_plus1  = kth_votes + 1;
  assign kth_votes_minus1 = (kth_votes > 0) ? (kth_votes - 1) : 8'd0;

  // Load candidate data (asynchronous, registered on next clock)
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < C; i = i + 1) begin
        votes_r[i] <= 8'd0;
        times_r[i] <= 8'd0;
      end
    end else begin
      if (load_data && (candidate_id < C)) begin
        votes_r[candidate_id] <= current_votes;
        times_r[candidate_id] <= last_vote_time;
      end
    end
  end

  // Compute result vector and drive sequential output
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= ST_IDLE;
      cycle    <= 6'd0;
      done     <= 1'b0;
      read_ptr <= 3'd0;
      result   <= 2'd0;
      result_vec <= 16'd0;
      // Initialize sort registers with identity (id 0..7)
      for (i = 0; i < C; i = i + 1) begin
        s_votes_r[i] <= 8'd0;
        s_times_r[i] <= 8'd0;
        s_id_r[i]    <= i[2:0];
      end
    end else begin
      // Default outputs
      result <= 2'd0;

      case (state)
        ST_IDLE: begin
          done <= 1'b0;
          // Prepare sorting pipeline inputs from storage
          for (i = 0; i < C; i = i + 1) begin
            s_votes_r[i] <= votes_r[i];
            s_times_r[i] <= times_r[i];
            s_id_r[i]    <= i[2:0];
          end
          cycle <= 6'd0;
          read_ptr <= 3'd0;
          if (start) begin
            state <= ST_WORK;
          end
        end

        ST_WORK: begin
          // Parallel sorting network (8 stages, 8 cycles)
          sort_stage(s_votes_r, s_times_r, s_id_r, 6'd0);
          sort_stage(s_votes_r, s_times_r, s_id_r, 6'd1);
          sort_stage(s_votes_r, s_times_r, s_id_r, 6'd2);
          sort_stage(s_votes_r, s_times_r, s_id_r, 6'd3);
          sort_stage(s_votes_r, s_times_r, s_id_r, 6'd4);
          sort_stage(s_votes_r, s_times_r, s_id_r, 6'd5);
          sort_stage(s_votes_r, s_times_r, s_id_r, 6'd6);
          sort_stage(s_votes_r, s_times_r, s_id_r, 6'd7);

          if (cycle >= 6'd7) begin
            // Determine result_vec after sorting completes (descending votes, asc time for tie)
            // For each candidate j, decide 1,2,3.
            // In all seats (k>=n): everyone is 1.
            if (k >= n) begin
              result_vec <= { {16{1'b1}} }; // placeholder; will overwrite per-candidate below
            end else begin
              result_vec <= 16'd0;
            end

            // Set per-candidate codes (explicit to remain portable)
            // Candidate 0
            if (k >= n) begin
              result_vec[1:0] <= 2'b01; // 1
            end else begin
              result_vec[1:0] <= classify(rank0_i, rank0_v, 0, k, kth_votes, kth_is_tie, k_valid, n);
            end
            // Candidate 1
            if (k >= n) begin
              result_vec[3:2] <= 2'b01;
            end else begin
              result_vec[3:2] <= classify(rank1_i, rank1_v, 1, k, kth_votes, kth_is_tie, k_valid, n);
            end
            // Candidate 2
            if (k >= n) begin
              result_vec[5:4] <= 2'b01;
            end else begin
              result_vec[5:4] <= classify(rank2_i, rank2_v, 2, k, kth_votes, kth_is_tie, k_valid, n);
            end
            // Candidate 3
            if (k >= n) begin
              result_vec[7:6] <= 2'b01;
            end else begin
              result_vec[7:6] <= classify(rank3_i, rank3_v, 3, k, kth_votes, kth_is_tie, k_valid, n);
            end
            // Candidate 4
            if (k >= n) begin
              result_vec[9:8] <= 2'b01;
            end else begin
              result_vec[9:8] <= classify(rank4_i, rank4_v, 4, k, kth_votes, kth_is_tie, k_valid, n);
            end
            // Candidate 5
            if (k >= n) begin
              result_vec[11:10] <= 2'b01;
            end else begin
              result_vec[11:10] <= classify(rank5_i, rank5_v, 5, k, kth_votes, kth_is_tie, k_valid, n);
            end
            // Candidate 6
            if (k >= n) begin
              result_vec[13:12] <= 2'b01;
            end else begin
              result_vec[13:12] <= classify(rank6_i, rank6_v, 6, k, kth_votes, kth_is_tie, k_valid, n);
            end
            // Candidate 7
            if (k >= n) begin
              result_vec[15:14] <= 2'b01;
            end else begin
              result_vec[15:14] <= classify(rank7_i, rank7_v, 7, k, kth_votes, kth_is_tie, k_valid, n);
            end

            state <= ST_DONE;
            done  <= 1'b1;
            read_ptr <= 3'd0;
          end else begin
            cycle <= cycle + 1;
          end
        end

        ST_DONE: begin
          // Sequential result output: present 2 bits per candidate in order of candidate_id (0..n-1)
          if (read_ptr < n) begin
            result <= result_vec[read_ptr*2 +: 2];
            read_ptr <= read_ptr + 1;
          end else begin
            result <= 2'd0;
          end

          // Stay done=1 until start triggers a new run or user resets
          if (start) begin
            state <= ST_WORK;
            done  <= 1'b0;
            cycle <= 6'd0;
            // Re-seed sort registers to reflect latest storage contents
            for (i = 0; i < C; i = i + 1) begin
              s_votes_r[i] <= votes_r[i];
              s_times_r[i] <= times_r[i];
              s_id_r[i]    <= i[2:0];
            end
            read_ptr <= 3'd0;
          end
        end

        default: state <= ST_IDLE;
      endcase
    end
  end

  // Function: classify a candidate into 1/2/3
  function [1:0] classify;
    input [2:0] cid;
    input [7:0] cvotes;
    input [2:0] rank;       // rank in sorted order (0=best)
    input [2:0] kseats;
    input [7:0] kth_votes_in;
    input kth_is_tie_in;
    input k_valid_in;
    input [2:0] n_cands;
    begin
      if (kseats >= n_cands) begin
        classify = 2'b01; // everyone guaranteed
      end else if (!k_valid_in) begin
        classify = 2'b11; // invalid k -> no chance
      end else begin
        if (rank < kseats) begin
          classify = 2'b01; // guaranteed seat
        end else if (kth_is_tie_in) begin
          // Within tie at boundary: if one more vote can surpass/join, consider possible
          if ((cvotes + 1) >= kth_votes_in) begin
            classify = 2'b10; // possible
          end else begin
            classify = 2'b11; // no chance
          end
        end else begin
          // Not in tie: possible if within remaining votes of kth
          if ((kth_votes_in >= cvotes) && ((kth_votes_in - cvotes) <= m_remaining)) begin
            classify = 2'b10; // possible
          end else begin
            classify = 2'b11; // no chance
          end
        end
      end
    end
  endfunction

  // Sorting network stage (bitonic-like with fixed comparators per stage)
  // Executes one stage per cycle, at cycle 0..7
  task sort_stage;
    inout [7:0] vv [0:C-1];
    inout [7:0] tt [0:C-1];
    inout [2:0] ii [0:C-1];
    input [5:0] stage;
    reg dir_asc; // 0: compare desc, 1: compare asc (we keep desc for votes, asc for time)
    begin
      dir_asc = 1'b0; // always sort by votes descending (time ascending as secondary)
      // Fixed comparator network per stage (8 stages, 8 candidates)
      compare_swap(vv, tt, ii, 0, 1, dir_asc);
      compare_swap(vv, tt, ii, 2, 3, dir_asc);
      compare_swap(vv, tt, ii, 4, 5, dir_asc);
      compare_swap(vv, tt, ii, 6, 7, dir_asc);
      compare_swap(vv, tt, ii, 0, 2, dir_asc);
      compare_swap(vv, tt, ii, 1, 3, dir_asc);
      compare_swap(vv, tt, ii, 4, 6, dir_asc);
      compare_swap(vv, tt, ii, 5, 7, dir_asc);
      compare_swap(vv, tt, ii, 1, 2, dir_asc);
      compare_swap(vv, tt, ii, 5, 6, dir_asc);
      compare_swap(vv, tt, ii, 0, 4, dir_asc);
      compare_swap(vv, tt, ii, 1, 5, dir_asc);
      compare_swap(vv, tt, ii, 2, 6, dir_asc);
      compare_swap(vv, tt, ii, 3, 7, dir_asc);
      compare_swap(vv, tt, ii, 3, 5, dir_asc);
      compare_swap(vv, tt, ii, 2, 4, dir_asc);
      compare_swap(vv, tt, ii, 1, 4, dir_asc);
      compare_swap(vv, tt, ii, 3, 6, dir_asc);
      // Stage-dependent final swaps for even/odd stages (odd-even transposition feel)
      if (stage[0] == 1'b0) begin
        compare_swap(vv, tt, ii, 0, 3, dir_asc);
        compare_swap(vv, tt, ii, 1, 7, dir_asc);
        compare_swap(vv, tt, ii, 2, 5, dir_asc);
        compare_swap(vv, tt, ii, 4, 6, dir_asc);
      end else begin
        compare_swap(vv, tt, ii, 0, 1, dir_asc);
        compare_swap(vv, tt, ii, 2, 3, dir_asc);
        compare_swap(vv, tt, ii, 4, 5, dir_asc);
        compare_swap(vv, tt, ii, 6, 7, dir_asc);
      end
    end
  endtask

  // Compare-swap by: primary key votes desc, secondary key time asc
  task compare_swap;
    inout [7:0] vv [0:C-1];
    inout [7:0] tt [0:C-1];
    inout [2:0] ii [0:C-1];
    input [2:0] a, b;
    input asc; // unused here (we keep desc on votes, asc on time)
    reg swap;
    begin
      // Determine if a should come after b (swap required)
      // swap = (votes_a < votes_b) || (votes_a == votes_b && time_a > time_b)
      swap = (vv[a] < vv[b]) || ((vv[a] == vv[b]) && (tt[a] > tt[b]));
      if (swap) begin
        vv[a] <= vv[b]; vv[b] <= vv[a];
        tt[a] <= tt[b]; tt[b] <= tt[a];
        ii[a] <= ii[b]; ii[b] <= ii[a];
      end
    end
  endtask

endmodule
