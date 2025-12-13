module guitar_hero_scorer(
  input  clk,
  input  rst_n,
  input  start,
  input  [3:0]  n_notes,
  input  [1:0]  p_phrases,
  input  [15:0] notes [15:0],
  input  [15:0] sp_starts [3:0],
  input  [15:0] sp_ends   [3:0],
  output reg [7:0] max_score,
  output reg       done
);

  // Internal state machine
  typedef enum logic [2:0] {
    IDLE  = 3'd0,
    INIT  = 3'd1,
    LOAD_COMBO = 3'd2,
    ACCUM_NOTES = 3'd3,
    UPDATE_MAX  = 3'd4,
    NEXT_COMBO  = 3'd5,
    FINISH      = 3'd6
  } state_t;

  state_t state, next_state;

  // Combination index (up to 2^4 = 16 combos)
  reg [3:0] combo_idx;
  reg [3:0] combo_limit; // (1 << p_phrases)

  // Latched inputs for stability during computation
  reg [3:0]  n_notes_l;
  reg [1:0]  p_phrases_l;
  reg [15:0] notes_l     [15:0];
  reg [15:0] sp_starts_l [3:0];
  reg [15:0] sp_ends_l   [3:0];

  // For each combo, we treat each chosen phrase as an SP activation window.
  // SP active if note time is within any selected phrase interval.

  // Accumulators
  reg [7:0] cur_score;
  reg [3:0] note_idx;

  // One-hot mask for which phrases are used in current combo
  reg [3:0] phrase_sel;

  // Combinational: build phrase_sel from combo_idx and p_phrases_l
  integer i;
  always @* begin
    phrase_sel = 4'b0000;
    for (i = 0; i < 4; i = i + 1) begin
      if (i < p_phrases_l)
        phrase_sel[i] = combo_idx[i];
      else
        phrase_sel[i] = 1'b0;
    end
  end

  // Helper: check if a note is in any active phrase for this combo
  function automatic logic is_sp_active(
    input [15:0] t
  );
    logic active;
    integer j;
    begin
      active = 1'b0;
      for (j = 0; j < 4; j = j + 1) begin
        if (phrase_sel[j]) begin
          if ((t >= sp_starts_l[j]) && (t <= sp_ends_l[j]))
            active = 1'b1;
        end
      end
      is_sp_active = active;
    end
  endfunction

  // Synchronous state & latches
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      max_score  <= 8'd0;
      done       <= 1'b0;
      combo_idx  <= 4'd0;
      combo_limit<= 4'd0;
      n_notes_l  <= 4'd0;
      p_phrases_l<= 2'd0;
      note_idx   <= 4'd0;
      cur_score  <= 8'd0;
      // no need to reset arrays for functional behavior
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Latch inputs at start
            n_notes_l   <= n_notes;
            p_phrases_l <= p_phrases;
            for (i = 0; i < 16; i = i + 1) begin
              notes_l[i] <= notes[i];
            end
            for (i = 0; i < 4; i = i + 1) begin
              sp_starts_l[i] <= sp_starts[i];
              sp_ends_l[i]   <= sp_ends[i];
            end
            max_score  <= 8'd0;
          end
        end

        INIT: begin
          // Compute combo_limit = 1 << p_phrases_l
          case (p_phrases_l)
            2'd0: combo_limit <= 4'd1;   // only 0
            2'd1: combo_limit <= 4'd2;   // 0..1
            2'd2: combo_limit <= 4'd4;   // 0..3
            2'd3: combo_limit <= 4'd8;   // 0..7
            default: combo_limit <= 4'd16; // 0..15 for p=4
          endcase
          combo_idx <= 4'd0;
        end

        LOAD_COMBO: begin
          // Prepare to evaluate current combo
          note_idx  <= 4'd0;
          cur_score <= 8'd0;
        end

        ACCUM_NOTES: begin
          // For each note, add 1 or 2 depending on SP active
          if (note_idx < n_notes_l) begin
            if (is_sp_active(notes_l[note_idx])) begin
              cur_score <= cur_score + 8'd2;
            end else begin
              cur_score <= cur_score + 8'd1;
            end
            note_idx <= note_idx + 4'd1;
          end
        end

        UPDATE_MAX: begin
          if (cur_score > max_score)
            max_score <= cur_score;
        end

        NEXT_COMBO: begin
          combo_idx <= combo_idx + 4'd1;
        end

        FINISH: begin
          done <= 1'b1;
        end

        default: ;
      endcase
    end
  end

  // Next state logic
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = INIT;
      end

      INIT: begin
        next_state = LOAD_COMBO;
      end

      LOAD_COMBO: begin
        next_state = ACCUM_NOTES;
      end

      ACCUM_NOTES: begin
        if (note_idx >= n_notes_l)
          next_state = UPDATE_MAX;
      end

      UPDATE_MAX: begin
        if (combo_idx + 4'd1 >= combo_limit)
          next_state = FINISH;
        else
          next_state = NEXT_COMBO;
      end

      NEXT_COMBO: begin
        next_state = LOAD_COMBO;
      end

      FINISH: begin
        if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule