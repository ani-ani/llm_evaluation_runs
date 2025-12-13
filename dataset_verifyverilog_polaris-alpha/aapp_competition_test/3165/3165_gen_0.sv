module rook_attack_counter(
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

  // FSM states
  typedef enum logic [2:0] {
    IDLE        = 3'd0,
    REMOVE_OLD  = 3'd1,
    ADD_NEW     = 3'd2,
    COMPUTE     = 3'd3,
    DONE        = 3'd4
  } state_t;

  state_t state, next_state;

  // Rook storage: 4 entries
  reg [1:0] rook_r[0:3];
  reg [1:0] rook_c[0:3];
  reg [7:0] rook_p[0:3];
  reg       rook_v[0:3];

  // Compute iteration counters
  reg [1:0] cur_r;
  reg [1:0] cur_c;

  // Internal attacked count accumulator
  reg [4:0] attacked_count_next;

  // Combinational signals for current cell computation
  reg [7:0] xor_val;
  reg       is_attacked;

  integer i;

  // FSM next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start_move)
          next_state = REMOVE_OLD;
      end
      REMOVE_OLD: begin
        next_state = ADD_NEW;
      end
      ADD_NEW: begin
        next_state = COMPUTE;
      end
      COMPUTE: begin
        // After processing last cell (3,3), go to DONE
        if (cur_r == 2'd3 && cur_c == 2'd3)
          next_state = DONE;
      end
      DONE: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Combinational attacked_count_next and XOR for current cell
  always @(*) begin
    xor_val = 8'd0;

    // XOR rook powers in same row or column, excluding self if rook there
    for (i = 0; i < 4; i = i + 1) begin
      if (rook_v[i]) begin
        if ((rook_r[i] == cur_r) || (rook_c[i] == cur_c)) begin
          if (!((rook_r[i] == cur_r) && (rook_c[i] == cur_c))) begin
            xor_val = xor_val ^ rook_p[i];
          end
        end
      end
    end

    is_attacked = (xor_val != 8'd0);

    // Default passthrough
    attacked_count_next = attacked_count;

    // Update count only during COMPUTE
    if (state == COMPUTE) begin
      attacked_count_next = attacked_count + (is_attacked ? 5'd1 : 5'd0);
    end
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      attacked_count <= 5'd0;
      done <= 1'b0;
      cur_r <= 2'd0;
      cur_c <= 2'd0;
      for (i = 0; i < 4; i = i + 1) begin
        rook_r[i] <= 2'd0;
        rook_c[i] <= 2'd0;
        rook_p[i] <= 8'd0;
        rook_v[i] <= 1'b0;
      end
    end else begin
      state <= next_state;
      done <= 1'b0; // default, may be set in DONE state

      case (state)
        IDLE: begin
          attacked_count <= 5'd0;
          cur_r <= 2'd0;
          cur_c <= 2'd0;
        end

        REMOVE_OLD: begin
          // Clear any rook matching old_r, old_c
          for (i = 0; i < 4; i = i + 1) begin
            if (rook_v[i] && (rook_r[i] == old_r) && (rook_c[i] == old_c)) begin
              rook_v[i] <= 1'b0;
              rook_p[i] <= 8'd0;
            end
          end
        end

        ADD_NEW: begin
          // Insert / overwrite rook at incoming position.
          // Priority 1: If a rook already at that square, overwrite it.
          // Priority 2: Otherwise, first free slot.
          integer idx;
          bit placed;
          placed = 1'b0;

          // Overwrite if exists
          for (idx = 0; idx < 4; idx = idx + 1) begin
            if (rook_v[idx] && (rook_r[idx] == incoming_r) && (rook_c[idx] == incoming_c)) begin
              rook_r[idx] <= incoming_r;
              rook_c[idx] <= incoming_c;
              rook_p[idx] <= incoming_power;
              rook_v[idx] <= 1'b1;
              placed = 1'b1;
            end
          end

          // Place into first free slot if not placed yet
          if (!placed) begin
            for (idx = 0; idx < 4; idx = idx + 1) begin
              if (!rook_v[idx] && !placed) begin
                rook_r[idx] <= incoming_r;
                rook_c[idx] <= incoming_c;
                rook_p[idx] <= incoming_power;
                rook_v[idx] <= 1'b1;
                placed = 1'b1;
              end
            end
          end
        end

        COMPUTE: begin
          // Update attacked count using combinational result
          attacked_count <= attacked_count_next;

          // Advance to next cell (r,c) each cycle
          if (cur_c == 2'd3) begin
            cur_c <= 2'd0;
            cur_r <= cur_r + 2'd1;
          end else begin
            cur_c <= cur_c + 2'd1;
          end
        end

        DONE: begin
          // Signal completion for one cycle; attacked_count already final
          done <= 1'b1;
        end

        default: ;
      endcase
    end
  end

endmodule