module mirka_piano_solver(
  input  wire        clk,
  input  wire        rst_n,
  input  reg         start,
  input  reg  [2:0]  N,          // number of multi-keys (2..8)
  input  reg  signed [7:0] a0,
  input  reg  signed [7:0] a1,
  input  reg  signed [7:0] a2,
  input  reg  signed [7:0] a3,
  input  reg  signed [7:0] a4,
  input  reg  signed [7:0] a5,
  input  reg  signed [7:0] a6,
  input  reg  signed [7:0] a7,
  output reg         done,
  output reg  [3:0]  max_correct,
  output reg  [7:0]  best_K
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE           = 3'd0,
    INIT           = 3'd1,
    EVAL_K_START   = 3'd2,
    EVAL_NOTE      = 3'd3,
    UPDATE_MAX     = 3'd4,
    FINISH         = 3'd5
  } state_t;

  state_t state, next_state;

  // Registers
  reg [7:0]  curr_K;              // current K being evaluated (0..255)
  reg [2:0]  note_idx;            // index of current note (0..7)
  reg signed [7:0] prev_note;     // previous playback note
  reg [3:0]  curr_correct;        // correct count for current K
  reg [2:0]  N_reg;               // latched N

  // Current note from input array
  wire signed [7:0] curr_a;
  assign curr_a = (note_idx == 3'd0) ? a0 :
                  (note_idx == 3'd1) ? a1 :
                  (note_idx == 3'd2) ? a2 :
                  (note_idx == 3'd3) ? a3 :
                  (note_idx == 3'd4) ? a4 :
                  (note_idx == 3'd5) ? a5 :
                  (note_idx == 3'd6) ? a6 :
                                      a7;

  // Next playback note candidates
  wire signed [7:0] next_up   = prev_note + $signed({1'b0, curr_K});
  wire signed [7:0] next_down = prev_note - $signed({1'b0, curr_K});
  wire signed [7:0] next_eq   = prev_note;

  // Determine best match for current input note
  wire match_up   = (next_up   == curr_a);
  wire match_down = (next_down == curr_a);
  wire match_eq   = (next_eq   == curr_a);

  // Priority: up > down > equal (arbitrary but deterministic)
  wire any_match  = match_up | match_down | match_eq;
  wire signed [7:0] chosen_next = match_up   ? next_up :
                                  match_down ? next_down :
                                  match_eq   ? next_eq :
                                              prev_note;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      done         <= 1'b0;
      max_correct  <= 4'd0;
      best_K       <= 8'd0;
      curr_K       <= 8'd0;
      note_idx     <= 3'd0;
      prev_note    <= 8'sd0;
      curr_correct <= 4'd0;
      N_reg        <= 3'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Latch N and initialize globals
            N_reg        <= N;
            max_correct  <= 4'd0;
            best_K       <= 8'd0;
            curr_K       <= 8'd0;
            curr_correct <= 4'd0;
            note_idx     <= 3'd0;
            prev_note    <= a0; // first note
          end
        end

        INIT: begin
          // For each new K: first note always matches and counted
          curr_correct <= (N_reg != 3'd0) ? 4'd1 : 4'd0;
          note_idx     <= 3'd1;     // move to second note
          prev_note    <= a0;       // first playback equals first input
        end

        EVAL_K_START: begin
          // Nothing additional; transition into EVAL_NOTE
        end

        EVAL_NOTE: begin
          if (note_idx < N_reg) begin
            // Compare and advance sequence
            if (any_match)
              curr_correct <= curr_correct + 4'd1;
            prev_note <= chosen_next;

            // Move to next note index
            note_idx <= note_idx + 3'd1;
          end
        end

        UPDATE_MAX: begin
          // After finishing all notes for current K, update global max
          if (curr_correct > max_correct) begin
            max_correct <= curr_correct;
            best_K      <= curr_K;
          end else if (curr_correct == max_correct) begin
            // Keep smallest K (do nothing since curr_K increases)
          end

          // Prepare next K
          if (curr_K != 8'hFF) begin
            curr_K       <= curr_K + 8'd1;
            curr_correct <= 4'd0;
            note_idx     <= 3'd0;
            prev_note    <= a0;
          end
        end

        FINISH: begin
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = INIT;
      end

      INIT: begin
        // Go to EVAL_K_START to begin evaluating notes for current K
        if (N_reg <= 3'd1) begin
          // Only one note: immediately update max
          next_state = UPDATE_MAX;
        end else begin
          next_state = EVAL_K_START;
        end
      end

      EVAL_K_START: begin
        // Start evaluating from note_idx = 1
        next_state = EVAL_NOTE;
      end

      EVAL_NOTE: begin
        if (note_idx >= N_reg) begin
          // Finished all notes for this K
          next_state = UPDATE_MAX;
        end else begin
          next_state = EVAL_NOTE;
        end
      end

      UPDATE_MAX: begin
        if (curr_K == 8'hFF) begin
          // Last K processed
          next_state = FINISH;
        end else begin
          // Next K: go to INIT
          next_state = INIT;
        end
      end

      FINISH: begin
        // Stay finished until next start (optional: require start & IDLE via reset)
        if (!start)
          next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule