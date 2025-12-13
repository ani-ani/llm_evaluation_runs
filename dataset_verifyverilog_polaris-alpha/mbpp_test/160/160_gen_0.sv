module diophantine_solver(
  input        clk,
  input        rst_n,
  input        start,
  input  [7:0] a,
  input  [7:0] b,
  input  [7:0] n,
  output reg [7:0] x,
  output reg [7:0] y,
  output reg       done,
  output reg       no_sol
);

  // Internal state
  reg [7:0] i;               // current candidate for x
  reg       busy;            // 1 if computation in progress
  reg [15:0] prod_a;         // i * a (up to 255*255=65025)
  reg [15:0] remainder;      // n - i*a (will fit in 16 bits)
  reg [7:0]  div_cnt;        // divisor counter for division by b
  reg [15:0] rem_work;       // working remainder for division
  reg       div_active;      // 1 if division in progress
  reg       div_done;        // 1 when division completes
  reg       div_exact;       // 1 if division had no remainder
  reg [7:0] div_q;           // quotient result (candidate y)

  // Combinational signals
  wire [15:0] n_ext = {8'd0, n};
  wire [15:0] a_ext = {8'd0, a};
  wire [15:0] b_ext = {8'd0, b};

  // Main sequential process
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous active-low reset
      x          <= 8'd0;
      y          <= 8'd0;
      done       <= 1'b0;
      no_sol     <= 1'b0;
      i          <= 8'd0;
      busy       <= 1'b0;
      prod_a     <= 16'd0;
      remainder  <= 16'd0;
      div_cnt    <= 8'd0;
      rem_work   <= 16'd0;
      div_active <= 1'b0;
      div_done   <= 1'b0;
      div_exact  <= 1'b0;
      div_q      <= 8'd0;
    end else begin
      // Default outputs each cycle
      done   <= 1'b0;
      no_sol <= 1'b0;

      // Clear one-cycle division done flag by default
      div_done <= 1'b0;

      if (!busy) begin
        // Idle state: wait for start pulse
        if (start) begin
          busy       <= 1'b1;
          i          <= 8'd0;
          div_active <= 1'b0;
        end
      end else begin
        // Busy: performing search
        if (!div_active) begin
          // Not currently dividing: evaluate i * a vs n
          prod_a <= i * a_ext[7:0];

          // Use previous cycle's prod_a comparison safely by recomputing combinationally
          if ((i * a_ext[7:0]) > n_ext[7:0]) begin
            // i*a > n: no solution
            done       <= 1'b1;
            no_sol     <= 1'b1;
            busy       <= 1'b0;
          end else begin
            // i*a <= n: compute remainder and start division by b
            remainder  <= n_ext - (i * a_ext[7:0]);
            rem_work   <= n_ext - (i * a_ext[7:0]);
            div_cnt    <= 8'd0;
            div_q      <= 8'd0;
            div_exact  <= 1'b0;
            div_active <= 1'b1;
          end
        end else begin
          // Division in progress: compute remainder % b and quotient via iterative subtraction
          if (!div_done) begin
            if (rem_work >= b_ext) begin
              rem_work <= rem_work - b_ext;
              div_q    <= div_q + 8'd1;
              div_cnt  <= div_cnt + 8'd1;
            end else begin
              // Division complete: check exactness
              div_done  <= 1'b1;
              div_exact <= (rem_work == 16'd0);
            end
          end else begin
            // Division just completed this cycle
            div_active <= 1'b0;

            if (div_exact) begin
              // Found solution: x=i, y=div_q
              x      <= i;
              y      <= div_q;
              done   <= 1'b1;
              no_sol <= 1'b0;
              busy   <= 1'b0;
            end else begin
              // Not divisible: try next i
              i <= i + 8'd1;
              // Next cycle we'll recompute i*a and decide
            end
          end
        end
      end
    end
  end

endmodule