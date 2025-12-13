module temperature_predictor(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [11:0] temp_0,
  input  logic [11:0] temp_1,
  input  logic [11:0] temp_2,
  input  logic [11:0] temp_3,
  input  logic [11:0] temp_4,
  input  logic [11:0] temp_5,
  input  logic [11:0] temp_6,
  input  logic [11:0] temp_7,
  input  logic [2:0]  n,
  output logic [11:0] prediction,
  output logic        done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE      = 2'b00,
    COMPARE   = 2'b01,
    CALCULATE = 2'b10,
    DONE      = 2'b11
  } state_t;

  state_t state, next_state;

  // Internal signals
  logic signed [11:0] temps [0:7];
  logic signed [11:0] diff;
  logic [2:0]         idx;           // index for compare
  logic               is_ap;         // flag: still arithmetic progression
  logic               start_d;       // start edge detection (optional robustness)

  // Unpack temps into array for easier indexing
  always_comb begin
    temps[0] = temp_0;
    temps[1] = temp_1;
    temps[2] = temp_2;
    temps[3] = temp_3;
    temps[4] = temp_4;
    temps[5] = temp_5;
    temps[6] = temp_6;
    temps[7] = temp_7;
  end

  // Sequential state, counters, and flags
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      prediction <= '0;
      done       <= 1'b0;
      diff       <= '0;
      idx        <= 3'd0;
      is_ap      <= 1'b0;
      start_d    <= 1'b0;
    end else begin
      state   <= next_state;
      start_d <= start;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start && !start_d) begin
            // Latch initial common difference from first two temps
            diff  <= $signed(temp_1) - $signed(temp_0);
            idx   <= 3'd2;      // start comparison from index 2
            is_ap <= 1'b1;      // assume AP until disproven
          end
        end

        COMPARE: begin
          done <= 1'b0;
          // Only compare while idx < n and still AP
          if (is_ap && (idx < n)) begin
            if ($signed(temps[idx]) - $signed(temps[idx-1]) != diff)
              is_ap <= 1'b0;
            idx <= idx + 3'd1;
          end
        end

        CALCULATE: begin
          done <= 1'b0;
          // Compute prediction based on AP flag
          if (is_ap) begin
            prediction <= $signed(temps[n-1]) + diff;
          end else begin
            prediction <= $signed(temps[n-1]);
          end
        end

        DONE: begin
          done <= 1'b1;
        end

        default: begin
          done <= 1'b0;
        end
      endcase
    end
  end

  // Next state logic
  always_comb begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start && !start_d) begin
          // For n <= 2, progression is trivially arithmetic; go directly to CALCULATE
          if (n <= 3'd2)
            next_state = CALCULATE;
          else
            next_state = COMPARE;
        end
      end

      COMPARE: begin
        // When index reaches n or AP is broken, move to CALCULATE
        if (!is_ap || (idx >= n))
          next_state = CALCULATE;
      end

      CALCULATE: begin
        next_state = DONE;
      end

      DONE: begin
        // Wait for start to be deasserted to return to IDLE (simple handshake)
        if (!start)
          next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule