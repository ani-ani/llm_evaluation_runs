module missing_number_finder(
  input              clk,
  input              rst_n,
  input              start,
  input      [3:0]   array [0:7],
  output reg [3:0]   missing,
  output reg         done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE    = 2'b00,
    CHECK4  = 2'b01,
    CHECK6  = 2'b10,
    FINISH  = 2'b11
  } state_t;

  state_t state, next_state;

  reg [2:0] s, e;          // start and end indices (0..7)
  reg [2:0] mid;           // mid index

  // Sequential state and registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= IDLE;
      s       <= 3'd0;
      e       <= 3'd7;
      missing <= 4'd0;
      done    <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            s <= 3'd0;
            e <= 3'd7;
          end
        end

        CHECK4: begin
          // mid = 3
          // Decide next range based on array[3]
          if (array[3] == 4'd3) begin
            s <= 3'd4;
            e <= 3'd7;
          end else begin
            s <= 3'd0;
            e <= 3'd3;
          end
        end

        CHECK6: begin
          // mid = (s + e) >> 1 (either 1,2,5,6 depending on range)
          mid <= (s + e) >> 1;
          if (array[(s + e) >> 1] == {1'b0, (s + e) >> 1}) begin
            s <= ((s + e) >> 1) + 3'd1;
          end else begin
            e <= (s + e) >> 1;
          end
        end

        FINISH: begin
          missing <= {1'b0, s};
          done    <= 1'b1;
        end

        default: begin
          // Should not occur
          done <= 1'b0;
        end
      endcase
    end
  end

  // Combinational next state logic
  always @(*) begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start)
          next_state = CHECK4; // First check at mid=3
      end

      CHECK4: begin
        // After deciding 4-bit range, go to CHECK6 for refined checks
        next_state = CHECK6;
      end

      CHECK6: begin
        // After this step, we must have narrowed down s > e or ready for last comparison.
        // Since max 3 steps total, move to FINISH.
        next_state = FINISH;
      end

      FINISH: begin
        // Stay here until next start; result stable
        if (start)
          next_state = CHECK4;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule