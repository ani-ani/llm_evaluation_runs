module tv_recorder (
  input clk,
  input rst_n,
  input start,
  input [5:0] show_index,
  input [31:0] start_time,
  input [31:0] end_time,
  output reg [3:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    SORT_PASS_1,
    SORT_PASS_2,
    SORT_PASS_3,
    SORT_PASS_4,
    SORT_PASS_5,
    SORT_PASS_6,
    SORT_PASS_7,
    SCHEDULE_0,
    SCHEDULE_1,
    SCHEDULE_2,
    SCHEDULE_3,
    SCHEDULE_4,
    SCHEDULE_5,
    SCHEDULE_6,
    SCHEDULE_7,
    DONE
  } state_t;

  state_t state;

  // Show storage (8 shows, each with start and end time)
  reg [31:0] shows_start [0:7];
  reg [31:0] shows_end [0:7];

  // Temporary storage for sorting
  reg [31:0] temp_start [0:7];
  reg [31:0] temp_end [0:7];

  // Scheduling variables
  reg [31:0] slot0_end;
  reg [31:0] slot1_end;
  reg [3:0] count;

  // Control signals
  reg [2:0] pass_count;
  reg [2:0] schedule_count;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      pass_count <= 0;
      schedule_count <= 0;
      slot0_end <= 0;
      slot1_end <= 0;
      count <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SORT_PASS_1;
            pass_count <= 0;
            // Load initial shows
            shows_start[show_index] <= start_time;
            shows_end[show_index] <= end_time;
          end
        end

        SORT_PASS_1: begin
          state <= SORT_PASS_2;
          pass_count <= 1;
          // Copy to temp for sorting
          for (int i = 0; i < 8; i++) begin
            temp_start[i] <= shows_start[i];
            temp_end[i] <= shows_end[i];
          end
          // First pass of bubble sort
          for (int i = 0; i < 7; i++) begin
            if (temp_end[i] > temp_end[i+1]) begin
              // Swap
              reg [31:0] temp_s;
              reg [31:0] temp_e;
              temp_s = temp_start[i];
              temp_e = temp_end[i];
              temp_start[i] <= temp_start[i+1];
              temp_end[i] <= temp_end[i+1];
              temp_start[i+1] <= temp_s;
              temp_end[i+1] <= temp_e;
            end
          end
        end

        SORT_PASS_2: begin
          state <= SORT_PASS_3;
          pass_count <= 2;
          // Second pass
          for (int i = 0; i < 6; i++) begin
            if (temp_end[i] > temp_end[i+1]) begin
              reg [31:0] temp_s;
              reg [31:0] temp_e;
              temp_s = temp_start[i];
              temp_e = temp_end[i];
              temp_start[i] <= temp_start[i+1];
              temp_end[i] <= temp_end[i+1];
              temp_start[i+1] <= temp_s;
              temp_end[i+1] <= temp_e;
            end
          end
        end

        SORT_PASS_3: begin
          state <= SORT_PASS_4;
          pass_count <= 3;
          // Third pass
          for (int i = 0; i < 5; i++) begin
            if (temp_end[i] > temp_end[i+1]) begin
              reg [31:0] temp_s;
              reg [31:0] temp_e;
              temp_s = temp_start[i];
              temp_e = temp_end[i];
              temp_start[i] <= temp_start[i+1];
              temp_end[i] <= temp_end[i+1];
              temp_start[i+1] <= temp_s;
              temp_end[i+1] <= temp_e;
            end
          end
        end

        SORT_PASS_4: begin
          state <= SORT_PASS_5;
          pass_count <= 4;
          // Fourth pass
          for (int i = 0; i < 4; i++) begin
            if (temp_end[i] > temp_end[i+1]) begin
              reg [31:0] temp_s;
              reg [31:0] temp_e;
              temp_s = temp_start[i];
              temp_e = temp_end[i];
              temp_start[i] <= temp_start[i+1];
              temp_end[i] <= temp_end[i+1];
              temp_start[i+1] <= temp_s;
              temp_end[i+1] <= temp_e;
            end
          end
        end

        SORT_PASS_5: begin
          state <= SORT_PASS_6;
          pass_count <= 5;
          // Fifth pass
          for (int i = 0; i < 3; i++) begin
            if (temp_end[i] > temp_end[i+1]) begin
              reg [31:0] temp_s;
              reg [31:0] temp_e;
              temp_s = temp_start[i];
              temp_e = temp_end[i];
              temp_start[i] <= temp_start[i+1];
              temp_end[i] <= temp_end[i+1];
              temp_start[i+1] <= temp_s;
              temp_end[i+1] <= temp_e;
            end
          end
        end

        SORT_PASS_6: begin
          state <= SORT_PASS_7;
          pass_count <= 6;
          // Sixth pass
          for (int i = 0; i < 2; i++) begin
            if (temp_end[i] > temp_end[i+1]) begin
              reg [31:0] temp_s;
              reg [31:0] temp_e;
              temp_s = temp_start[i];
              temp_e = temp_end[i];
              temp_start[i] <= temp_start[i+1];
              temp_end[i] <= temp_end[i+1];
              temp_start[i+1] <= temp_s;
              temp_end[i+1] <= temp_e;
            end
          end
        end

        SORT_PASS_7: begin
          state <= SCHEDULE_0;
          pass_count <= 7;
          // Seventh pass
          if (temp_end[0] > temp_end[1]) begin
            reg [31:0] temp_s;
            reg [31:0] temp_e;
            temp_s = temp_start[0];
            temp_e = temp_end[0];
            temp_start[0] <= temp_start[1];
            temp_end[0] <= temp_end[1];
            temp_start[1] <= temp_s;
            temp_end[1] <= temp_e;
          end
          // Copy sorted shows back
          for (int i = 0; i < 8; i++) begin
            shows_start[i] <= temp_start[i];
            shows_end[i] <= temp_end[i];
          end
          // Initialize scheduling
          slot0_end <= 0;
          slot1_end <= 0;
          count <= 0;
          schedule_count <= 0;
        end

        SCHEDULE_0: begin
          state <= SCHEDULE_1;
          schedule_count <= 1;
          // Check first show
          if (shows_end[0] >= slot0_end && shows_start[0] >= slot0_end) begin
            slot0_end <= shows_end[0];
            count <= count + 1;
          end else if (shows_end[0] >= slot1_end && shows_start[0] >= slot1_end) begin
            slot1_end <= shows_end[0];
            count <= count + 1;
          end
        end

        SCHEDULE_1: begin
          state <= SCHEDULE_2;
          schedule_count <= 2;
          // Check second show
          if (shows_end[1] >= slot0_end && shows_start[1] >= slot0_end) begin
            slot0_end <= shows_end[1];
            count <= count + 1;
          end else if (shows_end[1] >= slot1_end && shows_start[1] >= slot1_end) begin
            slot1_end <= shows_end[1];
            count <= count + 1;
          end
        end

        SCHEDULE_2: begin
          state <= SCHEDULE_3;
          schedule_count <= 3;
          // Check third show
          if (shows_end[2] >= slot0_end && shows_start[2] >= slot0_end) begin
            slot0_end <= shows_end[2];
            count <= count + 1;
          end else if (shows_end[2] >= slot1_end && shows_start[2] >= slot1_end) begin
            slot1_end <= shows_end[2];
            count <= count + 1;
          end
        end

        SCHEDULE_3: begin
          state <= SCHEDULE_4;
          schedule_count <= 4;
          // Check fourth show
          if (shows_end[3] >= slot0_end && shows_start[3] >= slot0_end) begin
            slot0_end <= shows_end[3];
            count <= count + 1;
          end else if (shows_end[3] >= slot1_end && shows_start[3] >= slot1_end) begin
            slot1_end <= shows_end[3];
            count <= count + 1;
          end
        end

        SCHEDULE_4: begin
          state <= SCHEDULE_5;
          schedule_count <= 5;
          // Check fifth show
          if (shows_end[4] >= slot0_end && shows_start[4] >= slot0_end) begin
            slot0_end <= shows_end[4];
            count <= count + 1;
          end else if (shows_end[4] >= slot1_end && shows_start[4] >= slot1_end) begin
            slot1_end <= shows_end[4];
            count <= count + 1;
          end
        end

        SCHEDULE_5: begin
          state <= SCHEDULE_6;
          schedule_count <= 6;
          // Check sixth show
          if (shows_end[5] >= slot0_end && shows_start[5] >= slot0_end) begin
            slot0_end <= shows_end[5];
            count <= count + 1;
          end else if (shows_end[5] >= slot1_end && shows_start[5] >= slot1_end) begin
            slot1_end <= shows_end[5];
            count <= count + 1;
          end
        end

        SCHEDULE_6: begin
          state <= SCHEDULE_7;
          schedule_count <= 7;
          // Check seventh show
          if (shows_end[6] >= slot0_end && shows_start[6] >= slot0_end) begin
            slot0_end <= shows_end[6];
            count <= count + 1;
          end else if (shows_end[6] >= slot1_end && shows_start[6] >= slot1_end) begin
            slot1_end <= shows_end[6];
            count <= count + 1;
          end
        end

        SCHEDULE_7: begin
          state <= DONE;
          schedule_count <= 0;
          // Check eighth show
          if (shows_end[7] >= slot0_end && shows_start[7] >= slot0_end) begin
            slot0_end <= shows_end[7];
            count <= count + 1;
          end else if (shows_end[7] >= slot1_end && shows_start[7] >= slot1_end) begin
            slot1_end <= shows_end[7];
            count <= count + 1;
          end
        end

        DONE: begin
          done <= 1;
          result <= count;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule