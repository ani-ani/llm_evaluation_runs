module service_verifier(
  input clk, // Clock signal
  input rst_n, // Active-low reset
  input start, // Start processing (pulse or level)
  input [4:0][15:0] years_months, // [15:8]=year-1950, [7:0]=month, MSB of this 16b is valid flag per spec comment
  input [4:0][16:0] odos, // 5 odometer readings (17-bit each)
  output reg [1:0] status // 00=seems legit, 01=insufficient service, 10=tampered odometer
);

  // Internal representations
  // Extract fields: assuming spec: [31:16]=valid is inconsistent with 16-bit, so use MSB of 16-bit as valid flag.
  // [15] = valid, [14:7]=year-1950 (8 bits), [6:0] not enough for month, so instead follow detailed description:
  // Use: [15] valid, [14:7] year-1950, [6:0] month (1-12). If month out of range, it will naturally violate checks.

  // For compliance with the textual description, decode as:
  // valid  = years_months[i][15]
  // year_o = years_months[i][14:7]
  // month  = years_months[i][6:0]

  // FSM states
  typedef enum logic [2:0] {
    S_IDLE   = 3'd0,
    S_LATCH  = 3'd1,
    S_COMP12 = 3'd2,
    S_COMP23 = 3'd3,
    S_COMP34 = 3'd4,
    S_COMP45 = 3'd5,
    S_DONE   = 3'd6
  } state_t;

  state_t state, next_state;

  // Latched inputs
  reg [15:0] ym_latched [4:0];
  reg [16:0] odo_latched[4:0];

  // Months since epoch for each entry (need enough bits)
  // year_off up to 127, month up to 12 -> months_since_epoch < 127*12+12 < 1536 (11 bits)
  reg [10:0] months [4:0];
  reg       valid [4:0];

  // Flags
  reg insufficient_service;
  reg tampered_odo;

  // Counter to align 10-cycle processing
  // We'll design fixed schedule:
  // Cycle 0: IDLE
  // Cycle 1: LATCH (on start)
  // Cycle 2..5: COMP12..COMP45 (4 comparisons)
  // Cycle 6: DONE (status stable)
  // Remaining cycles (to reach 10) we stay in DONE; no functional change.
  reg [3:0] cycle_cnt;

  // Decode helper wires in a generate-like style (combinational from latched or input)
  integer i;

  // Latch inputs and compute months on transition into LATCH
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      cycle_cnt <= 4'd0;
      status <= 2'b00;
      insufficient_service <= 1'b0;
      tampered_odo <= 1'b0;
      for (i = 0; i < 5; i = i + 1) begin
        ym_latched[i] <= 16'd0;
        odo_latched[i] <= 17'd0;
        months[i] <= 11'd0;
        valid[i] <= 1'b0;
      end
    end else begin
      state <= next_state;

      // Cycle counter: runs during active sequence, holds in IDLE
      if (state == S_IDLE && !start)
        cycle_cnt <= 4'd0;
      else if (state == S_IDLE && start)
        cycle_cnt <= 4'd1;
      else if (state != S_IDLE)
        cycle_cnt <= cycle_cnt + 4'd1;

      case (state)
        S_IDLE: begin
          insufficient_service <= 1'b0;
          tampered_odo <= 1'b0;
          status <= 2'b00;
          // Nothing else
        end

        S_LATCH: begin
          // Latch inputs
          for (i = 0; i < 5; i = i + 1) begin
            ym_latched[i] <= years_months[i];
            odo_latched[i] <= odos[i];
            valid[i] <= years_months[i][15];
            // Decode year offset and month from fields
            // year_off = [14:7], month = [6:0]
            // months_since_epoch = year_off*12 + (month-1)
            // If month==0, result underflows logically and will likely break constraints.
            months[i] <= {4'd0, years_months[i][14:7]} * 11'd12 + ( {4'd0, years_months[i][6:0]} - 11'd1 );
          end
        end

        // COMPARE states: each processes one consecutive pair
        S_COMP12: begin
          // Compare entry 0 -> 1
          if (valid[0] && valid[1]) begin
            automatic integer dmon;
            automatic integer dodo;
            automatic integer cur_month;
            automatic integer prev_month;
            automatic integer cur_odo;
            automatic integer prev_odo;
            automatic integer min_km;
            automatic integer max_km;

            prev_month = months[0];
            cur_month  = months[1];
            dmon = cur_month - prev_month;

            prev_odo = odo_latched[0];
            cur_odo  = odo_latched[1];
            if (cur_odo >= prev_odo)
              dodo = cur_odo - prev_odo;
            else
              dodo = 100000 - prev_odo + cur_odo;

            // Constraint i: delta_odo in [2000*dmon, 20000*dmon]
            if (dmon <= 0) begin
              tampered_odo <= 1'b1;
            end else begin
              min_km = 2000 * dmon;
              max_km = 20000 * dmon;
              if (dodo < min_km || dodo > max_km)
                tampered_odo <= 1'b1;
            end

            // Constraint ii: interval must be <=30000 km OR <=12 months
            if (!( (dodo <= 30000) || (dmon <= 12) ))
              insufficient_service <= 1'b1;
          end
        end

        S_COMP23: begin
          if (valid[1] && valid[2]) begin
            automatic integer dmon;
            automatic integer dodo;
            automatic integer cur_month;
            automatic integer prev_month;
            automatic integer cur_odo;
            automatic integer prev_odo;
            automatic integer min_km;
            automatic integer max_km;

            prev_month = months[1];
            cur_month  = months[2];
            dmon = cur_month - prev_month;

            prev_odo = odo_latched[1];
            cur_odo  = odo_latched[2];
            if (cur_odo >= prev_odo)
              dodo = cur_odo - prev_odo;
            else
              dodo = 100000 - prev_odo + cur_odo;

            if (dmon <= 0) begin
              tampered_odo <= 1'b1;
            end else begin
              min_km = 2000 * dmon;
              max_km = 20000 * dmon;
              if (dodo < min_km || dodo > max_km)
                tampered_odo <= 1'b1;
            end

            if (!( (dodo <= 30000) || (dmon <= 12) ))
              insufficient_service <= 1'b1;
          end
        end

        S_COMP34: begin
          if (valid[2] && valid[3]) begin
            automatic integer dmon;
            automatic integer dodo;
            automatic integer cur_month;
            automatic integer prev_month;
            automatic integer cur_odo;
            automatic integer prev_odo;
            automatic integer min_km;
            automatic integer max_km;

            prev_month = months[2];
            cur_month  = months[3];
            dmon = cur_month - prev_month;

            prev_odo = odo_latched[2];
            cur_odo  = odo_latched[3];
            if (cur_odo >= prev_odo)
              dodo = cur_odo - prev_odo;
            else
              dodo = 100000 - prev_odo + cur_odo;

            if (dmon <= 0) begin
              tampered_odo <= 1'b1;
            end else begin
              min_km = 2000 * dmon;
              max_km = 20000 * dmon;
              if (dodo < min_km || dodo > max_km)
                tampered_odo <= 1'b1;
            end

            if (!( (dodo <= 30000) || (dmon <= 12) ))
              insufficient_service <= 1'b1;
          end
        end

        S_COMP45: begin
          if (valid[3] && valid[4]) begin
            automatic integer dmon;
            automatic integer dodo;
            automatic integer cur_month;
            automatic integer prev_month;
            automatic integer cur_odo;
            automatic integer prev_odo;
            automatic integer min_km;
            automatic integer max_km;

            prev_month = months[3];
            cur_month  = months[4];
            dmon = cur_month - prev_month;

            prev_odo = odo_latched[3];
            cur_odo  = odo_latched[4];
            if (cur_odo >= prev_odo)
              dodo = cur_odo - prev_odo;
            else
              dodo = 100000 - prev_odo + cur_odo;

            if (dmon <= 0) begin
              tampered_odo <= 1'b1;
            end else begin
              min_km = 2000 * dmon;
              max_km = 20000 * dmon;
              if (dodo < min_km || dodo > max_km)
                tampered_odo <= 1'b1;
            end

            if (!( (dodo <= 30000) || (dmon <= 12) ))
              insufficient_service <= 1'b1;
          end
        end

        S_DONE: begin
          // Set final status; tampered has priority
          if (tampered_odo)
            status <= 2'b10;
          else if (insufficient_service)
            status <= 2'b01;
          else
            status <= 2'b00;
          // Remain stable; cycle_cnt continues but does not affect outputs.
        end

        default: begin
          // Should not occur
        end
      endcase
    end
  end

  // Next state logic
  always_comb begin
    next_state = state;

    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_LATCH;
      end

      S_LATCH: begin
        next_state = S_COMP12;
      end

      S_COMP12: begin
        next_state = S_COMP23;
      end

      S_COMP23: begin
        next_state = S_COMP34;
      end

      S_COMP34: begin
        next_state = S_COMP45;
      end

      S_COMP45: begin
        next_state = S_DONE;
      end

      S_DONE: begin
        // Hold result; allow restart when start is asserted again
        if (start)
          next_state = S_LATCH;
        else
          next_state = S_DONE;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

endmodule