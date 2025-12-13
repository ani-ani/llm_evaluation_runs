module perfect_squares (
  input  logic       clk,
  input  logic       rst_n,
  input  logic       start,
  input  logic [7:0] a,
  input  logic [7:0] b,
  output logic [7:0] square_out,
  output logic       valid,
  output logic       done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE        = 2'b00,
    PROCESSING  = 2'b01
  } state_t;

  state_t       state, next_state;
  logic [7:0]   reg_a, reg_b;
  logic [3:0]   j;              // 1..15 is sufficient since 15*15=225 < 255, 16*16 exceeds 8 bits
  logic [8:0]   square_ext;     // 9-bit to safely detect > b
  logic         start_d;
  logic         start_pulse;

  // Edge detect for start (1-cycle pulse on rising edge)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d <= 1'b0;
    end else begin
      start_d <= start;
    end
  end

  assign start_pulse = start & ~start_d;

  // Sequential state and registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      reg_a      <= 8'd0;
      reg_b      <= 8'd0;
      j          <= 4'd0;
      square_out <= 8'd0;
      valid      <= 1'b0;
      done       <= 1'b0;
    end else begin
      // Default outputs each cycle
      valid <= 1'b0;
      done  <= 1'b0;

      state <= next_state;

      case (state)
        IDLE: begin
          // Wait for a start pulse; support back-to-back operations
          if (start_pulse) begin
            reg_a <= a;
            reg_a <= b;
            j     <= 4'd1;
          end
        end

        PROCESSING: begin
          // Compute square for current j
          square_ext = j * j;

          // Output valid square within range
          if ((square_ext[7:0] >= reg_a) && (square_ext[7:0] <= reg_b)) begin
            square_out <= square_ext[7:0];
            valid      <= 1'b1;
          end

          // Prepare for next iteration
          j <= j + 4'd1;
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

  // Next-state logic and done pulse generation
  always_comb begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start_pulse) begin
          next_state = PROCESSING;
        end
      end

      PROCESSING: begin
        // Use current j to decide if next j*j exceeds reg_b
        // Since j is incremented after using it, compare with (j+1)*(j+1)
        logic [4:0] j_next;
        logic [9:0] square_next_ext;

        j_next          = j + 4'd1;
        square_next_ext = j_next * j_next;

        if (square_next_ext[8:0] > {1'b0, reg_b}) begin
          // Will finish on next cycle: emit done pulse and go IDLE
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Generate done pulse aligned with completion condition
  // Done should assert for 1 cycle when we transition from PROCESSING to IDLE
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
    end else begin
      if (state == PROCESSING) begin
        // Predict completion based on next j
        logic [4:0] j_next;
        logic [9:0] square_next_ext;
        j_next          = j + 4'd1;
        square_next_ext = j_next * j_next;
        if (square_next_ext[8:0] > {1'b0, reg_b}) begin
          done <= 1'b1;
        end
      end
    end
  end

endmodule