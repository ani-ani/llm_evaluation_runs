module rook_attack_counter (
  input clk, // Clock
  input rst_n, // Active-low reset
  input start_move, // Pulse high to start processing
  input [1:0] incoming_r, // New row (2 bits for N=4)
  input [1:0] incoming_c, // New column
  input [7:0] incoming_power, // Rook power (8-bit max 255)
  input [1:0] old_r, // Old position (use 0,0 if placement)
  input [1:0] old_c, // Old column
  output reg [4:0] attacked_count, // Number attacked (0-16)
  output reg done // High when result ready
);

  // Board size constant
  localparam N = 4;
  localparam NUM_ROOKS = 4;
  localparam W = $clog2(NUM_ROOKS);

  // FSM states
  typedef enum logic [2:0] {IDLE, REMOVE_OLD, ADD_NEW, COMPUTE, DONE} fsm_state_t;
  fsm_state_t state, next_state;

  // Rook storage
  reg [1:0] rook_r [0:NUM_ROOKS-1];
  reg [1:0] rook_c [0:NUM_ROOKS-1];
  reg [7:0] rook_power [0:NUM_ROOKS-1];
  reg rook_valid [0:NUM_ROOKS-1];

  // Bookkeeping
  reg [2:0] rook_count;  // 0..4
  reg [1:0] rr_index;    // round-robin eviction index

  // Compute pipeline state
  reg [3:0] field_idx;   // 0..15
  reg [2:0] board_rook_count_snapshot; // captured at start of compute

  // Internal signals
  wire [1:0] field_r, field_c;
  wire [3:0] field_idx_next;
  wire [3:0] row_match_oh, col_match_oh;
  wire [15:0] row_mask, col_mask;
  wire [15:0] sel_mask;
  wire [7:0] xor_comb;
  wire field_has_rook;
  wire add_first_empty_valid;
  reg [1:0] first_empty_idx;

  // field coordinate
  assign field_r = field_idx[3:2];  // row = idx/4
  assign field_c = field_idx[1:0];  // col = idx%4

  // Next field index (wrap after 15)
  assign field_idx_next = (field_idx == 4'b1111) ? 4'b0000 : (field_idx + 1);

  // One-hot masks for row/col matches per rook slot
  genvar g;
  generate
    for (g = 0; g < NUM_ROOKS; g++) begin : gen_masks
      assign row_match_oh[g] = (rook_r[g] == field_r) ? 1'b1 : 1'b0;
      assign col_match_oh[g] = (rook_c[g] == field_c) ? 1'b1 : 1'b0;
    end
  endgenerate

  // Per-rook masks valid & in same row/column
  generate
    for (g = 0; g < NUM_ROOKS; g++) begin : gen_sel
      assign row_mask[g] = rook_valid[g] & row_match_oh[g];
      assign col_mask[g] = rook_valid[g] & col_match_oh[g];
    end
  endgenerate

  // Combined mask: same row XOR same column
  assign sel_mask = row_mask ^ col_mask;

  // XOR combine all selected rook powers
  assign xor_comb = ({8{sel_mask[0]}} & rook_power[0]) ^
                    ({8{sel_mask[1]}} & rook_power[1]) ^
                    ({8{sel_mask[2]}} & rook_power[2]) ^
                    ({8{sel_mask[3]}} & rook_power[3]);

  // Whether the current field itself has a rook
  assign field_has_rook = rook_valid[0] & (rook_r[0] == field_r) & (rook_c[0] == field_c) |
                          rook_valid[1] & (rook_r[1] == field_r) & (rook_c[1] == field_c) |
                          rook_valid[2] & (rook_r[2] == field_r) & (rook_c[2] == field_c) |
                          rook_valid[3] & (rook_r[3] == field_r) & (rook_c[3] == field_c);

  // Helper to find first empty slot in a single cycle
  assign add_first_empty_valid = (rook_valid[0] == 1'b0) ? 1'b1 :
                                 (rook_valid[1] == 1'b0) ? 1'b1 :
                                 (rook_valid[2] == 1'b0) ? 1'b1 :
                                 (rook_valid[3] == 1'b0) ? 1'b1 : 1'b0;

  // FSM sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      for (int i = 0; i < NUM_ROOKS; i++) begin
        rook_valid[i] <= 1'b0;
        rook_r[i] <= 2'b0;
        rook_c[i] <= 2'b0;
        rook_power[i] <= 8'b0;
      end
      rook_count <= 3'b0;
      rr_index <= 2'b0;
      attacked_count <= 5'b0;
      done <= 1'b0;
      field_idx <= 4'b0;
      board_rook_count_snapshot <= 3'b0;
      first_empty_idx <= 2'b0;
    end else begin
      state <= next_state;
      done <= 1'b0; // default, overridden in DONE
      // latch first empty index as soon as we enter ADD_NEW (if any)
      if (state == ADD_NEW) begin
        if (!add_first_empty_valid) begin
          // no empty slot found, keep previous value (won't be used)
        end else begin
          if (!rook_valid[0]) first_empty_idx <= 2'b0;
          else if (!rook_valid[1]) first_empty_idx <= 2'b1;
          else if (!rook_valid[2]) first_empty_idx <= 2'b2;
          else first_empty_idx <= 2'b3;
        end
      end

      // State behaviors
      case (state)
        REMOVE_OLD: begin
          // Remove matching rook at old_r/old_c (if present)
          for (int i = 0; i < NUM_ROOKS; i++) begin
            if (rook_valid[i] && (rook_r[i] == old_r) && (rook_c[i] == old_c)) begin
              rook_valid[i] <= 1'b0;
              rook_r[i] <= 2'b0;
              rook_c[i] <= 2'b0;
              rook_power[i] <= 8'b0;
            end
          end
          // Update count and RR index
          rook_count <= (rook_count > 0) ? (rook_count - 1) : 3'b0;
          if (rook_count > 0) begin
            // keep rr_index unchanged to point to slot just freed
          end
        end

        ADD_NEW: begin
          if (add_first_empty_valid) begin
            // Place in first empty slot
            rook_valid[first_empty_idx] <= 1'b1;
            rook_r[first_empty_idx] <= incoming_r;
            rook_c[first_empty_idx] <= incoming_c;
            rook_power[first_empty_idx] <= incoming_power;
            rook_count <= rook_count + 1;
          end else begin
            // Board full: evict round-robin
            rook_valid[rr_index] <= 1'b1;
            rook_r[rr_index] <= incoming_r;
            rook_c[rr_index] <= incoming_c;
            rook_power[rr_index] <= incoming_power;
            // count unchanged, advance RR index
            rr_index <= rr_index + 1;
          end
        end

        COMPUTE: begin
          field_idx <= field_idx_next;
          if (field_idx == 4'b1111) begin
            // Last field processed; done will be set in next state transition
          end
        end

        DONE: begin
          done <= 1'b1;
        end

        default: begin
          // IDLE: nothing to do
        end
      endcase

      if (next_state == COMPUTE && state != COMPUTE) begin
        // Entering compute: latch current rook count and reset field index
        field_idx <= 4'b0;
        board_rook_count_snapshot <= rook_count;
      end
    end
  end

  // FSM next-state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start_move) next_state = REMOVE_OLD;
      end
      REMOVE_OLD: begin
        next_state = ADD_NEW;
      end
      ADD_NEW: begin
        next_state = COMPUTE;
      end
      COMPUTE: begin
        if (field_idx == 4'b1111) next_state = DONE;
        else next_state = COMPUTE;
      end
      DONE: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Attacked count accumulation during COMPUTE
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      attacked_count <= 5'b0;
    end else begin
      if (state == COMPUTE) begin
        // For a valid board (board_rook_count_snapshot > 0), attacked if XOR != 0
        if (board_rook_count_snapshot > 0) begin
          if (|xor_comb) begin
            if (field_idx == 4'b1111)
              attacked_count <= attacked_count + 1; // final increment in last cycle
          end
        end
        // Increment at the end of each field (except the very first, where attacked_count is 0)
        if (field_idx != 4'b0000) begin
          if (board_rook_count_snapshot == 0) begin
            // No rooks -> attacked_count remains 0
          end else begin
            attacked_count <= attacked_count + (|xor_comb ? 1 : 0);
          end
        end
      end else if (next_state == DONE) begin
        // On transition to DONE, nothing extra (already captured in last compute cycle)
      end
    end
  end

endmodule
