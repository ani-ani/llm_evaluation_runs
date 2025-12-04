module mirka_piano_solver (
  input clk,
  input rst_n,
  input start,
  input [2:0] N,
  input [7:0] a0,a1,a2,a3,a4,a5,a6,a7,
  output logic done,
  output logic [3:0] max_correct,
  output logic [7:0] best_K
);

  enum logic [2:0] {IDLE, INIT, EVAL_K_START, EVAL_NOTE, UPDATE_MAX, FINISH} state, next_state;
  
  reg signed [7:0] a_array [0:7];
  reg [8:0] current_K;
  reg [3:0] N_val;
  reg [3:0] max_correct_reg;
  reg [7:0] best_K_reg;
  reg [3:0] note_index;
  reg [3:0] current_correct;
  reg signed [7:0] playback_note;
  
  logic signed [7:0] delta;
  logic signed [7:0] next_playback_note;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      max_correct_reg <= 1;
      best_K_reg <= 0;
      current_K <= 0;
      note_index <= 0;
      current_correct <= 0;
      playback_note <= 0;
      a_array <= '{default:0};
      N_val <= 2;
    end else begin
      state <= next_state;
      case (state)
        IDLE: done <= 0;
        INIT: begin
          a_array[0] <= a0;
          a_array[1] <= a1;
          a_array[2] <= a2;
          a_array[3] <= a3;
          a_array[4] <= a4;
          a_array[5] <= a5;
          a_array[6] <= a6;
          a_array[7] <= a7;
          N_val <= N + 3'd2;
          current_K <= 0;
          max_correct_reg <= 1;
          best_K_reg <= 0;
        end
        EVAL_K_START: begin
          playback_note <= a_array[0];
          current_correct <= 1;
          note_index <= 1;
        end
        EVAL_NOTE: begin
          if (next_playback_note == a_array[note_index]) 
            current_correct <= current_correct + 1;
          playback_note <= next_playback_note;
          note_index <= note_index + 1;
        end
        UPDATE_MAX: begin
          if (current_correct > max_correct_reg) begin
            max_correct_reg <= current_correct;
            best_K_reg <= current_K[7:0];
          end else if ((current_correct == max_correct_reg) && (current_K[7:0] < best_K_reg)) begin
            best_K_reg <= current_K[7:0];
          end
          current_K <= current_K + 1;
        end
        FINISH: done <= 1;
      endcase
    end
  end
  
  always_comb begin
    case (state)
      IDLE: next_state = (start) ? INIT : IDLE;
      INIT: next_state = EVAL_K_START;
      EVAL_K_START: next_state = EVAL_NOTE;
      EVAL_NOTE: next_state = (note_index < N_val) ? EVAL_NOTE : UPDATE_MAX;
      UPDATE_MAX: next_state = (current_K < 9'd256) ? EVAL_K_START : FINISH;
      FINISH: next_state = FINISH;
      default: next_state = IDLE;
    endcase
  end
  
  always_comb begin
    delta = a_array[note_index] - a_array[note_index - 1];
    if (delta > 0)
      next_playback_note = playback_note + current_K[7:0];
    else if (delta < 0)
      next_playback_note = playback_note - current_K[7:0];
    else
      next_playback_note = playback_note;
  end
  
  assign max_correct = max_correct_reg;
  assign best_K = best_K_reg;
  
endmodule