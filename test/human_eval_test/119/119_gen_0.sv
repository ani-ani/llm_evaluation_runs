module balanced_concatenation(
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0] str1_bits,
  input  [7:0] str2_bits,
  output reg result,
  output reg done
);

  // State encoding
  localparam IDLE         = 2'b00;
  localparam CHECK_ORDER1 = 2'b01;
  localparam CHECK_ORDER2 = 2'b10;
  localparam DONE         = 2'b11;

  reg [1:0] state, next_state;

  // Counters and tracking for order1 and order2
  reg [4:0] idx1;        // 0..15 for str1+str2
  reg [4:0] idx2;        // 0..15 for str2+str1

  reg signed [5:0] count1;
  reg signed [5:0] count2;

  reg invalid1;
  reg invalid2;

  reg [7:0] str1_reg;
  reg [7:0] str2_reg;

  // Sequential state/register update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= IDLE;
      idx1     <= 5'd0;
      idx2     <= 5'd0;
      count1   <= 6'sd0;
      count2   <= 6'sd0;
      invalid1 <= 1'b0;
      invalid2 <= 1'b0;
      str1_reg <= 8'd0;
      str2_reg <= 8'd0;
      result   <= 1'b0;
      done     <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done   <= 1'b0;
          result <= 1'b0;
          if (start) begin
            // Latch inputs at start
            str1_reg <= str1_bits;
            str2_reg <= str2_bits;
            // Initialize for checking order1
            idx1     <= 5'd0;
            idx2     <= 5'd0;
            count1   <= 6'sd0;
            count2   <= 6'sd0;
            invalid1 <= 1'b0;
            invalid2 <= 1'b0;
          end
        end

        CHECK_ORDER1: begin
          // Process one position per cycle for str1+str2 into count1/invalid1
          if (idx1 < 5'd16 && !invalid1) begin
            // Determine bit for order1: str1_reg then str2_reg
            // idx1 0..7 -> str1_reg[7-idx1]
            // idx1 8..15 -> str2_reg[7-(idx1-8)]
            if (idx1 < 5'd8) begin
              if (str1_reg[7-idx1] == 1'b0)
                count1 <= count1 + 6'sd1;
              else
                count1 <= count1 - 6'sd1;
            end else begin
              if (str2_reg[7-(idx1-5'd8)] == 1'b0)
                count1 <= count1 + 6'sd1;
              else
                count1 <= count1 - 6'sd1;
            end

            // Early invalid check based on current count1 after update (combinational in next cycle)
            if (count1 < 6'sd0)
              invalid1 <= 1'b1;

            idx1 <= idx1 + 5'd1;
          end

          // Reset order2 trackers here for next phase (once, when entering state)
          if (idx1 == 5'd0) begin
            idx2     <= 5'd0;
            count2   <= 6'sd0;
            invalid2 <= 1'b0;
          end
        end

        CHECK_ORDER2: begin
          // Process one position per cycle for str2+str1 into count2/invalid2
          if (idx2 < 5'd16 && !invalid2) begin
            // Determine bit for order2: str2_reg then str1_reg
            // idx2 0..7 -> str2_reg[7-idx2]
            // idx2 8..15 -> str1_reg[7-(idx2-8)]
            if (idx2 < 5'd8) begin
              if (str2_reg[7-idx2] == 1'b0)
                count2 <= count2 + 6'sd1;
              else
                count2 <= count2 - 6'sd1;
            end else begin
              if (str1_reg[7-(idx2-5'd8)] == 1'b0)
                count2 <= count2 + 6'sd1;
              else
                count2 <= count2 - 6'sd1;
            end

            if (count2 < 6'sd0)
              invalid2 <= 1'b1;

            idx2 <= idx2 + 5'd1;
          end
        end

        DONE: begin
          done <= 1'b1;
          // result assigned in next_state logic when transitioning to DONE
        end
      endcase
    end
  end

  // Next state and result control
  always @(*) begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start)
          next_state = CHECK_ORDER1;
      end

      CHECK_ORDER1: begin
        // When finished processing 16 chars or invalid detected, decide next
        if (invalid1 || (idx1 == 5'd16)) begin
          // Valid if no invalid and count1==0 at completion
          if (!invalid1 && (count1 == 6'sd0)) begin
            next_state = DONE;
          end else begin
            next_state = CHECK_ORDER2;
          end
        end
      end

      CHECK_ORDER2: begin
        if (invalid2 || (idx2 == 5'd16)) begin
          next_state = DONE;
        end
      end

      DONE: begin
        if (!start)
          next_state = IDLE;
      end
    endcase
  end

  // Result determination (sequential in DONE state)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 1'b0;
    end else begin
      if (state == CHECK_ORDER1 && next_state == DONE) begin
        // Order1 valid path
        result <= 1'b1;
      end else if (state == CHECK_ORDER1 && next_state == CHECK_ORDER2) begin
        // Order1 failed, keep result 0 for now
        result <= 1'b0;
      end else if (state == CHECK_ORDER2 && next_state == DONE) begin
        // Decide based on order2
        if (!invalid2 && (count2 == 6'sd0))
          result <= 1'b1;
        else
          result <= 1'b0;
      end else if (state == IDLE && !start) begin
        result <= 1'b0;
      end
    end
  end

endmodule