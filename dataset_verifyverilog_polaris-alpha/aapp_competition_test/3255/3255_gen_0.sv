module hopper_path_finder(
  input clk,
  input rst_n,
  input start,
  input [2:0] D,
  input [7:0] M,
  input [15:0] arr_0,
  input [15:0] arr_1,
  input [15:0] arr_2,
  input [15:0] arr_3,
  input [15:0] arr_4,
  input [15:0] arr_5,
  input [15:0] arr_6,
  input [15:0] arr_7,
  output reg [3:0] max_length,
  output reg done
);

  // Internal array storage
  reg signed [15:0] arr[7:0];

  // Path mask indicates visited nodes in current path
  reg [7:0] current_mask;
  reg [2:0] current_idx;
  reg [3:0] current_len;

  // Absolute difference and checks
  reg signed [15:0] diff;
  reg [7:0] candidate_mask;
  reg [2:0] i;

  // State machine
  typedef enum logic [2:0] {
    IDLE          = 3'd0,
    INIT          = 3'd1,
    COMPARE_JUMP  = 3'd2,
    UPDATE_PATH   = 3'd3,
    DONE          = 3'd4
  } state_t;

  state_t state, next_state;

  // Control and helper registers
  reg [5:0] cycle_cnt;          // for worst-case latency tracking (optional bound)
  reg [2:0] start_node;         // current starting node for exploration
  reg       exploring;          // flag indicating active exploration from a start_node
  reg       any_extension;      // indicates if any new jump was possible in this sweep
  reg [7:0] next_mask_accum;    // accumulate next-step expansions
  reg [7:0] next_mask;          // mask of all nodes reachable in one more hop

  // Parallel validity wires for 8 potential targets
  reg [7:0] valid_target;

  // Signed version of M for comparisons
  wire signed [7:0] M_s = M;

  // Combinational: compute next_mask and any_extension based on current_mask/current_idx not used; BFS-style from set bits
  integer j, k;

  always @(*) begin
    // Parallel check for all j as potential targets from any visited node i
    // BFS-like expansion: from any set bit in current_mask, try all j
    next_mask_accum = 8'b0;

    // For each source i in current_mask, test all destinations j in range and constraints
    for (j = 0; j < 8; j = j + 1) begin
      valid_target[j] = 1'b0;
      if (!current_mask[j]) begin
        // Check if there exists some i in current_mask such that jump i->j is valid
        for (k = 0; k < 8; k = k + 1) begin
          if (current_mask[k]) begin
            // Jump distance constraint
            if ((j > k ? (j - k) : (k - j)) <= D && (j != k)) begin
              // Value difference constraint |arr[j] - arr[k]| <= M
              diff = arr[j] - arr[k];
              if (diff < 0)
                diff = -diff;
              if (diff <= {{8{M_s[7]}}, M_s}) begin
                valid_target[j] = 1'b1;
              end
            end
          end
        end
      end
      if (valid_target[j]) begin
        next_mask_accum[j] = 1'b1;
      end
    end

    next_mask = next_mask_accum & ~current_mask;
    any_extension = (next_mask != 8'b0);
  end

  // State transition
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = INIT;
      end

      INIT: begin
        next_state = COMPARE_JUMP;
      end

      COMPARE_JUMP: begin
        next_state = UPDATE_PATH;
      end

      UPDATE_PATH: begin
        if (!any_extension) begin
          // No more extensions from this start_node
          if (start_node == 3'd7)
            next_state = DONE;
          else
            next_state = INIT; // move to next start_node
        end else begin
          // Continue exploring from same start_node
          next_state = COMPARE_JUMP;
        end
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
      state        <= IDLE;
      max_length   <= 4'd0;
      done         <= 1'b0;
      cycle_cnt    <= 6'd0;
      start_node   <= 3'd0;
      current_mask <= 8'd0;
      current_len  <= 4'd0;
      current_idx  <= 3'd0;

      arr[0] <= 16'd0;
      arr[1] <= 16'd0;
      arr[2] <= 16'd0;
      arr[3] <= 16'd0;
      arr[4] <= 16'd0;
      arr[5] <= 16'd0;
      arr[6] <= 16'd0;
      arr[7] <= 16'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done       <= 1'b0;
          cycle_cnt  <= 6'd0;
          max_length <= 4'd0;
          if (start) begin
            // Latch array on start
            arr[0] <= arr_0;
            arr[1] <= arr_1;
            arr[2] <= arr_2;
            arr[3] <= arr_3;
            arr[4] <= arr_4;
            arr[5] <= arr_5;
            arr[6] <= arr_6;
            arr[7] <= arr_7;
            start_node <= 3'd0;
          end
        end

        INIT: begin
          cycle_cnt    <= cycle_cnt + 6'd1;
          // Initialize exploration from current start_node
          current_mask <= (8'b1 << start_node);
          current_len  <= 4'd1; // path includes starting node
          current_idx  <= start_node;
        end

        COMPARE_JUMP: begin
          cycle_cnt <= cycle_cnt + 6'd1;
          // combinational next_mask/any_extension already computed
        end

        UPDATE_PATH: begin
          cycle_cnt <= cycle_cnt + 6'd1;
          if (any_extension) begin
            // Extend path: BFS layer, conservatively increase length by 1
            current_mask <= current_mask | next_mask;
            current_len  <= current_len + 4'd1;
          end else begin
            // No extension possible; finalize this start_node's path length
            if (current_len > max_length)
              max_length <= current_len;

            if (start_node != 3'd7) begin
              // Move to next start node
              start_node <= start_node + 3'd1;
            end
          end
        end

        DONE: begin
          done <= 1'b1;
          // Hold results until start is deasserted and FSM returns to IDLE
        end

        default: begin
          // safety
        end
      endcase
    end
  end

endmodule