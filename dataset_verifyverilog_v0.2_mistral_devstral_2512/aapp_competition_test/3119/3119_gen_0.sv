module guitar_hero_scoring (
  input clk,
  input rst_n,
  input start,
  input [3:0] num_notes,
  input [3:0] num_phrases,
  input [15:0] note_times [0:15],
  input [15:0] phrase_start [0:3],
  input [15:0] phrase_end [0:3],
  output reg [15:0] max_score,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    LOAD,
    COMPUTE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [3:0] num_notes_reg;
  reg [3:0] num_phrases_reg;
  reg [15:0] note_times_reg [0:15];
  reg [15:0] phrase_start_reg [0:3];
  reg [15:0] phrase_end_reg [0:3];
  reg [15:0] phrase_duration [0:3];
  reg [15:0] total_charge;
  reg [15:0] max_score_reg;
  reg [4:0] compute_counter;
  reg [15:0] current_charge;
  reg [15:0] current_bonus;
  reg [15:0] activation_start;
  reg [15:0] activation_end;
  reg [4:0] note_counter;
  reg [4:0] phrase_counter;
  reg [4:0] load_counter;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      max_score <= 0;
      load_counter <= 0;
      compute_counter <= 0;
      note_counter <= 0;
      phrase_counter <= 0;
      current_charge <= 0;
      current_bonus <= 0;
      activation_start <= 0;
      activation_end <= 0;
      total_charge <= 0;
      max_score_reg <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = LOAD;
      end
      LOAD: begin
        if (load_counter == 15 + 3 + 3) next_state = COMPUTE;
      end
      COMPUTE: begin
        if (compute_counter == 16) next_state = DONE;
      end
      DONE: begin
        if (start) next_state = LOAD;
      end
    endcase
  end

  // Load state logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      num_notes_reg <= 0;
      num_phrases_reg <= 0;
      for (int i = 0; i < 16; i++) note_times_reg[i] <= 0;
      for (int i = 0; i < 4; i++) begin
        phrase_start_reg[i] <= 0;
        phrase_end_reg[i] <= 0;
        phrase_duration[i] <= 0;
      end
      load_counter <= 0;
    end else if (current_state == LOAD) begin
      case (load_counter)
        0: num_notes_reg <= num_notes;
        1: num_phrases_reg <= num_phrases;
        2: note_times_reg[0] <= note_times[0];
        3: note_times_reg[1] <= note_times[1];
        4: note_times_reg[2] <= note_times[2];
        5: note_times_reg[3] <= note_times[3];
        6: note_times_reg[4] <= note_times[4];
        7: note_times_reg[5] <= note_times[5];
        8: note_times_reg[6] <= note_times[6];
        9: note_times_reg[7] <= note_times[7];
        10: note_times_reg[8] <= note_times[8];
        11: note_times_reg[9] <= note_times[9];
        12: note_times_reg[10] <= note_times[10];
        13: note_times_reg[11] <= note_times[11];
        14: note_times_reg[12] <= note_times[12];
        15: note_times_reg[13] <= note_times[13];
        16: note_times_reg[14] <= note_times[14];
        17: note_times_reg[15] <= note_times[15];
        18: phrase_start_reg[0] <= phrase_start[0];
        19: phrase_end_reg[0] <= phrase_end[0];
        20: phrase_start_reg[1] <= phrase_start[1];
        21: phrase_end_reg[1] <= phrase_end[1];
        22: phrase_start_reg[2] <= phrase_start[2];
        23: phrase_end_reg[2] <= phrase_end[2];
        24: phrase_start_reg[3] <= phrase_start[3];
        25: phrase_end_reg[3] <= phrase_end[3];
        default: ;
      endcase
      load_counter <= load_counter + 1;
    end
  end

  // Compute state logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      compute_counter <= 0;
      note_counter <= 0;
      phrase_counter <= 0;
      current_charge <= 0;
      current_bonus <= 0;
      activation_start <= 0;
      activation_end <= 0;
      max_score_reg <= 0;
    end else if (current_state == COMPUTE) begin
      if (compute_counter == 0) begin
        // Pre-calculate phrase durations
        for (int i = 0; i < 4; i++) begin
          if (i < num_phrases_reg) begin
            phrase_duration[i] = phrase_end_reg[i] - phrase_start_reg[i];
          end else begin
            phrase_duration[i] = 0;
          end
        end
        // Calculate total charge
        total_charge = 0;
        for (int i = 0; i < 4; i++) begin
          total_charge = total_charge + phrase_duration[i];
        end
      end

      // Evaluate activation starting at each note
      if (compute_counter < num_notes_reg) begin
        activation_start = note_times_reg[compute_counter];
        activation_end = activation_start + total_charge;

        // Calculate charge (sum of non-overlapping phrases)
        current_charge = 0;
        for (int i = 0; i < 4; i++) begin
          if (i < num_phrases_reg) begin
            if (phrase_end_reg[i] <= activation_start || phrase_start_reg[i] >= activation_end) begin
              current_charge = current_charge + phrase_duration[i];
            end
          end
        end

        // Count bonus notes
        current_bonus = 0;
        for (int i = 0; i < 16; i++) begin
          if (i < num_notes_reg && note_times_reg[i] >= activation_start && note_times_reg[i] < activation_end) begin
            current_bonus = current_bonus + 1;
          end
        end

        // Update max score
        if (current_bonus > max_score_reg) begin
          max_score_reg = current_bonus;
        end
      end

      compute_counter <= compute_counter + 1;
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      max_score <= 0;
      done <= 0;
    end else begin
      if (current_state == DONE) begin
        max_score <= num_notes_reg + max_score_reg;
        done <= 1;
      end else begin
        done <= 0;
      end
    end
  end

endmodule