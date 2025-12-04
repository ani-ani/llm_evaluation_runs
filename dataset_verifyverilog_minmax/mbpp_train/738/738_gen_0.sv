module geometric_sum (
  input  clk,
  input  rst_n,
  input  start,        // Pulse high to start
  input  [3:0] n,       // Max value 8 (compute up to 1/256)
  output reg [31:0] sum_q16, // Q16.16 result
  output reg done
);

  // State machine
  localparam IDLE = 2'b00;
  localparam RUN  = 2'b01;
  localparam DONE = 2'b10;

  reg [1:0] state, next_state;
  reg [3:0] k;           // Current term index (0..n)
  reg [3:0] n_reg;       // Snapshot of n when start is detected
  reg start_d;
  wire start_edge;
  reg [31:0] sum;

  // Start edge detection (combinational, relies on clocked input)
  always @(*) begin
    start_d = start;
  end
  assign start_edge = start && !start_d;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Registered datapath and control signals
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      k      <= 4'd0;
      n_reg  <= 4'd0;
      sum    <= 32'd0;
      sum_q16<= 32'd0;
      done   <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done   <= 1'b0;
          if (start_edge) begin
            n_reg  <= n;           // snapshot n
            k      <= 4'd0;        // start at k=0
            sum    <= 32'd0;       // reset sum
            sum_q16<= 32'd0;       // clear output while running
          end
        end

        RUN: begin
          // Compute and add the current term: 1/(2^k) => 2^(16-k) in Q16.16
          // For k in [0..8], this is exact; for k>16 the term is 0.
          if (k <= 4'd16) begin
            sum <= sum + (32'd1 << (16 - k));
          end
          k <= k + 1;

          // Finish when k exceeds n (after n+1 terms added: k=0..n)
          if (k >= n_reg) begin
            done   <= 1'b1;
            sum_q16<= sum;
          end else begin
            done   <= 1'b0;
          end
        end

        DONE: begin
          // Hold final result and done high until next start
          done   <= 1'b1;
          sum_q16<= sum;
        end

        default: begin
          // Catch-all
          done   <= 1'b0;
          sum_q16<= 32'd0;
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    case (state)
      IDLE: next_state = start_edge ? RUN : IDLE;
      RUN:  next_state = (k >= n_reg) ? DONE : RUN;
      DONE: next_state = start_edge ? RUN : DONE;
      default: next_state = IDLE;
    endcase
  end

endmodule
