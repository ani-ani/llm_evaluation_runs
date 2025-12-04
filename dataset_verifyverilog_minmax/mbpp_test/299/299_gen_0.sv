module max_aggregate (
  input clk,
  input rst_n,
  input start,
  input [2:0] student_id,
  input [7:0] marks,
  input last_entry,
  output reg [2:0] max_id,
  output reg [10:0] max_score,
  output reg done
);

  // Parameters
  localparam NUM_STUDENTS = 5;
  localparam MAX_ENTRIES  = 8;
  localparam ACC_W        = 11; // 8-bit marks x 8 entries fits in 11 bits

  // FSM state encoding
  localparam IDLE   = 2'b00;
  localparam RUN    = 2'b01;
  localparam POST1  = 2'b10; // 1 cycle after last valid entry
  localparam DONE   = 2'b11; // 2 cycles after last valid entry (result + done pulse)

  // Registers
  reg [1:0] state, next_state;
  reg [10:0] acc [0:NUM_STUDENTS-1];
  reg [2:0] entry_count;
  reg last_q, last_q2; // pipeline for last_entry
  reg [2:0] id_pipe;   // pipeline for student_id
  reg [7:0] marks_pipe; // pipeline for marks

  integer i;

  // Sequential logic (clock and reset)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < NUM_STUDENTS; i = i + 1) acc[i] <= '0;
      entry_count <= '0;
      last_q      <= 1'b0;
      last_q2     <= 1'b0;
      id_pipe     <= '0;
      marks_pipe  <= '0;
      state       <= IDLE;
      max_id      <= '0;
      max_score   <= '0;
      done        <= 1'b0;
    end else begin
      // Default assignments
      done   <= 1'b0;
      state  <= next_state;

      // Update pipelines
      last_q  <= last_entry;
      last_q2 <= last_q;
      id_pipe <= student_id;
      marks_pipe <= marks;

      case (state)
        IDLE: begin
          // Hold outputs cleared in IDLE
          for (i = 0; i < NUM_STUDENTS; i = i + 1) acc[i] <= '0;
          entry_count <= '0;
        end

        RUN: begin
          // Accumulate current input for the specified student (processed 1 cycle after being applied)
          if (|acc) acc <= acc; // keep other accumulators unchanged
          acc[id_pipe] <= acc[id_pipe] + marks_pipe;
          entry_count <= entry_count + 1;
        end

        POST1: begin
          // No changes; waiting one cycle before computing result
        end

        DONE: begin
          // Assert done for exactly one cycle
          done <= 1'b1;
        end
      endcase
    end
  end

  // Next-state and result logic (combinational)
  always @(*) begin
    next_state = state;

    case (state)
      IDLE:   next_state = start ? RUN : IDLE;
      RUN:    next_state = (last_q | (entry_count == (MAX_ENTRIES-1))) ? POST1 : RUN;
      POST1:  next_state = DONE;
      DONE:   next_state = start ? RUN : IDLE; // Allow immediate restart
      default: next_state = IDLE;
    endcase
  end

  // Compute max after last valid entry + 1 cycle (in POST1)
  always @(*) begin
    if (state == POST1) begin
      // Determine student with maximum aggregate
      max_id = 3'd0;
      max_score = acc[0];
      for (i = 1; i < NUM_STUDENTS; i = i + 1) begin
        if (acc[i] > max_score) begin
          max_score = acc[i];
          max_id    = i[2:0];
        end
      end
    end else begin
      // Hold previous result outside POST1; outputs are cleared in IDLE via reset
      max_id    = 3'd0;
      max_score = 11'd0;
    end
  end

endmodule
