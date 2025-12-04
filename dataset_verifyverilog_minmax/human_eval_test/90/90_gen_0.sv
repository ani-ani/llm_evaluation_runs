module next_smallest (
  input clk,
  input rst_n,
  input start,
  input [7:0] valid_mask,
  input [7:0] data [0:7],
  output reg [7:0] second_smallest,
  output reg found,
  output reg done
);

  typedef enum logic [3:0] {
    IDLE      = 4'b0000,
    COMPARE_0 = 4'b0001,
    COMPARE_1 = 4'b0010,
    COMPARE_2 = 4'b0011,
    COMPARE_3 = 4'b0100,
    COMPARE_4 = 4'b0101,
    COMPARE_5 = 4'b0110,
    COMPARE_6 = 4'b0111,
    COMPARE_7 = 4'b1000,
    FINISH    = 4'b1001
  } state_t;

  state_t state, next_state;

  // Internal tracking of min and second min
  reg [7:0] min_val, second_min;
  reg [7:0] next_min_val, next_second_min;

  // Sentinel for "not set yet" (max positive 8-bit signed)
  localparam [7:0] SENTINEL = 8'h7F;

  // Track whether we have seen at least one valid element
  reg any_valid, next_any_valid;

  // State register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done  <= 1'b0;
    end else begin
      state <= next_state;
      done  <= (next_state == FINISH);
    end
  end

  // Outputs and internal tracking (sequential update)
  always_ff @(posedge clk) begin
    min_val      <= next_min_val;
    second_min   <= next_second_min;
    any_valid    <= next_any_valid;
    found        <= (next_state == FINISH) ? (next_second_min != SENTINEL) : 1'b0;
    second_smallest <= (next_state == FINISH) ? next_second_min : 8'h00;
  end

  // Compute next state and next tracking values
  always_comb begin
    // Defaults: hold current values
    next_state     = state;
    next_min_val   = min_val;
    next_second_min= second_min;
    next_any_valid = any_valid;

    case (state)
      IDLE: begin
        if (start) begin
          next_state     = COMPARE_0;
          next_min_val   = SENTINEL;
          next_second_min= SENTINEL;
          next_any_valid = 1'b0;
        end
      end

      COMPARE_0: begin
        if (valid_mask[0]) begin
          next_any_valid = 1'b1;
          if (data[0] < min_val) begin
            next_second_min = min_val;
            next_min_val    = data[0];
          end else if (data[0] < second_min && data[0] != min_val) begin
            next_second_min = data[0];
          end
          next_state = COMPARE_1;
        end else begin
          next_state = COMPARE_1;
        end
      end

      COMPARE_1: begin
        if (valid_mask[1]) begin
          next_any_valid = 1'b1;
          if (data[1] < min_val) begin
            next_second_min = min_val;
            next_min_val    = data[1];
          end else if (data[1] < second_min && data[1] != min_val) begin
            next_second_min = data[1];
          end
          next_state = COMPARE_2;
        end else begin
          next_state = COMPARE_2;
        end
      end

      COMPARE_2: begin
        if (valid_mask[2]) begin
          next_any_valid = 1'b1;
          if (data[2] < min_val) begin
            next_second_min = min_val;
            next_min_val    = data[2];
          end else if (data[2] < second_min && data[2] != min_val) begin
            next_second_min = data[2];
          end
          next_state = COMPARE_3;
        end else begin
          next_state = COMPARE_3;
        end
      end

      COMPARE_3: begin
        if (valid_mask[3]) begin
          next_any_valid = 1'b1;
          if (data[3] < min_val) begin
            next_second_min = min_val;
            next_min_val    = data[3];
          end else if (data[3] < second_min && data[3] != min_val) begin
            next_second_min = data[3];
          end
          next_state = COMPARE_4;
        end else begin
          next_state = COMPARE_4;
        end
      end

      COMPARE_4: begin
        if (valid_mask[4]) begin
          next_any_valid = 1'b1;
          if (data[4] < min_val) begin
            next_second_min = min_val;
            next_min_val    = data[4];
          end else if (data[4] < second_min && data[4] != min_val) begin
            next_second_min = data[4];
          end
          next_state = COMPARE_5;
        end else begin
          next_state = COMPARE_5;
        end
      end

      COMPARE_5: begin
        if (valid_mask[5]) begin
          next_any_valid = 1'b1;
          if (data[5] < min_val) begin
            next_second_min = min_val;
            next_min_val    = data[5];
          end else if (data[5] < second_min && data[5] != min_val) begin
            next_second_min = data[5];
          end
          next_state = COMPARE_6;
        end else begin
          next_state = COMPARE_6;
        end
      end

      COMPARE_6: begin
        if (valid_mask[6]) begin
          next_any_valid = 1'b1;
          if (data[6] < min_val) begin
            next_second_min = min_val;
            next_min_val    = data[6];
          end else if (data[6] < second_min && data[6] != min_val) begin
            next_second_min = data[6];
          end
          next_state = COMPARE_7;
        end else begin
          next_state = COMPARE_7;
        end
      end

      COMPARE_7: begin
        if (valid_mask[7]) begin
          next_any_valid = 1'b1;
          if (data[7] < min_val) begin
            next_second_min = min_val;
            next_min_val    = data[7];
          end else if (data[7] < second_min && data[7] != min_val) begin
            next_second_min = data[7];
          end
          next_state = FINISH;
        end else begin
          next_state = FINISH;
        end
      end

      FINISH: begin
        if (start) begin
          // Allow immediate re-start without returning to IDLE
          next_state     = COMPARE_0;
          next_min_val   = SENTINEL;
          next_second_min= SENTINEL;
          next_any_valid = 1'b0;
        end else begin
          next_state = FINISH;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule
