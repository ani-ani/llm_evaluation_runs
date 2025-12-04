module next_palindrome(
  input  wire        clk,
  input  wire        rst_n,
  input  wire        start,
  input  wire [15:0] num,
  output reg  [15:0] palindrome,
  output reg         done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    RUN   = 2'b01,
    FINISH= 2'b10
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [15:0] current;
  reg [7:0]  iter_cnt;        // up to 256 iterations
  reg        start_d;
  wire       start_pulse;

  // Palindrome check signals
  reg [15:0] val_reg;
  reg [3:0]  d0, d1, d2, d3, d4; // BCD digits: d4 d3 d2 d1 d0
  reg        is_pal;

  // Edge detect for start (1-cycle pulse)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      start_d <= 1'b0;
    else
      start_d <= start;
  end

  assign start_pulse = start & ~start_d;

  // Sequential state and main registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      current    <= 16'd0;
      iter_cnt   <= 8'd0;
      palindrome <= 16'd0;
      done       <= 1'b0;
      val_reg    <= 16'd0;
      d0         <= 4'd0;
      d1         <= 4'd0;
      d2         <= 4'd0;
      d3         <= 4'd0;
      d4         <= 4'd0;
      is_pal     <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start_pulse) begin
            // Initialize search
            current  <= num + 16'd1;
            iter_cnt <= 8'd0;
          end
        end

        RUN: begin
          // Perform BCD conversion and palindrome check for current
          // Capture value for conversion
          val_reg <= current;

          // Binary to BCD (double dabble) combinational-style inside clocked block
          // Working registers
          integer i;
          reg [27:0] shift_reg; // 16 bits data + 12 bits for 3 BCD digits extra, but we need 5 digits (20 bits).
          // Use 16 + 20 = 36 bits
          reg [35:0] work;

          // Initialize work with binary value in lower bits, BCD digits cleared
          work = 36'd0;
          work[15:0] = current;

          // 16 iterations of double dabble
          for (i = 0; i < 16; i = i + 1) begin
            // Adjust each BCD digit (5 digits: positions [35:32],[31:28],[27:24],[23:20],[19:16])
            if (work[19:16] >= 5) work[19:16] = work[19:16] + 4'd3; // d0
            if (work[23:20] >= 5) work[23:20] = work[23:20] + 4'd3; // d1
            if (work[27:24] >= 5) work[27:24] = work[27:24] + 4'd3; // d2
            if (work[31:28] >= 5) work[31:28] = work[31:28] + 4'd3; // d3
            if (work[35:32] >= 5) work[35:32] = work[35:32] + 4'd3; // d4
            // Shift left by 1
            work = work << 1;
          end

          // Extract BCD digits
          d0 <= work[19:16];
          d1 <= work[23:20];
          d2 <= work[27:24];
          d3 <= work[31:28];
          d4 <= work[35:32];

          // Palindrome check for this cycle using updated digits
          is_pal <= (work[19:16] == work[35:32]) && (work[23:20] == work[31:28]);

          // Decide based on palindrome and iteration count
          if (is_pal) begin
            palindrome <= current;
            done       <= 1'b1;
          end else if (iter_cnt == 8'd255) begin
            palindrome <= 16'd0;
            done       <= 1'b1;
          end else begin
            // Not found yet, increment and continue
            current  <= current + 16'd1;
            iter_cnt <= iter_cnt + 8'd1;
          end
        end

        FINISH: begin
          // Hold outputs until next start
          if (start_pulse) begin
            done     <= 1'b0;
            current  <= num + 16'd1;
            iter_cnt <= 8'd0;
          end
        end

        default: begin
          // Safety reset-like behavior
          state      <= IDLE;
          palindrome <= 16'd0;
          done       <= 1'b0;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start_pulse)
          next_state = RUN;
      end

      RUN: begin
        if (done)
          next_state = FINISH;
        else
          next_state = RUN;
      end

      FINISH: begin
        if (start_pulse)
          next_state = RUN;
        else
          next_state = FINISH;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule