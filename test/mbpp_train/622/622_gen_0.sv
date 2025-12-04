module sorted_arrays_median (
  input              clk,
  input              rst_n,
  input              start,
  input      [7:0]   arr1 [0:7],
  input      [7:0]   arr2 [0:7],
  input      [2:0]   n,
  output reg [8:0]   med_sum,
  output reg         done
);

  // State encoding
  localparam IDLE       = 2'd0;
  localparam PROCESSING = 2'd1;
  localparam DONE       = 2'd2;

  reg [1:0] state, next_state;

  reg [2:0] i;
  reg [2:0] j;
  reg [3:0] count;      // up to n+1 (max 8)

  reg [7:0] m1;
  reg [7:0] m2;

  // Sequential state and registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= IDLE;
      i       <= 3'd0;
      j       <= 3'd0;
      count   <= 4'd0;
      m1      <= 8'd0;
      m2      <= 8'd0;
      med_sum <= 9'd0;
      done    <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            i     <= 3'd0;
            j     <= 3'd0;
            count <= 4'd0;
            m1    <= 8'd0;
            m2    <= 8'd0;
          end
        end

        PROCESSING: begin
          // Perform one merge comparison step per cycle
          // Maintain previous (m1) and current (m2) selected values
          if (count == 4'd0) begin
            // First element selection
            if (arr1[i] <= arr2[j]) begin
              m2 <= arr1[i];
              if (i != 3'd7) i <= i + 3'd1;
            end else begin
              m2 <= arr2[j];
              if (j != 3'd7) j <= j + 3'd1;
            end
            count <= count + 4'd1;
          end else begin
            // Subsequent selections
            m1 <= m2;
            if (arr1[i] <= arr2[j]) begin
              m2 <= arr1[i];
              if (i != 3'd7) i <= i + 3'd1;
            end else begin
              m2 <= arr2[j];
              if (j != 3'd7) j <= j + 3'd1;
            end
            count <= count + 4'd1;
          end
        end

        DONE: begin
          done <= 1'b1;
        end

        default: begin
          // Should not occur
        end
      endcase

      // Latch med_sum when entering DONE
      if (state == PROCESSING && next_state == DONE) begin
        med_sum <= m1 + m2;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = PROCESSING;
      end

      PROCESSING: begin
        // After n+1 selected elements, move to DONE
        if (count == (n + 4'd1)) begin
          next_state = DONE;
        end
      end

      DONE: begin
        // Return to IDLE when start deasserted (simple handshake)
        if (!start)
          next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule