module lottery_probability(
  input  clk,
  input  rst_n,
  input  start,
  input  [4:0] m,
  input  [3:0] n,
  input  [3:0] t,
  input  [4:0] p,
  output reg [31:0] probability,
  output reg        done
);

  // States
  localparam IDLE      = 2'd0;
  localparam CALC_COMB = 2'd1;
  localparam DIVIDE    = 2'd2;
  localparam DONE      = 2'd3;

  reg [1:0] state, next_state;

  // Internal registers
  reg [4:0] m_r;
  reg [3:0] n_r;
  reg [3:0] t_r;
  reg [4:0] p_r;
  reg [4:0] k_min_r;
  reg [4:0] k_cur;
  reg [4:0] k_max_r;

  reg [39:0] numerator_sum;      // Accumulates sum of C(p,k)*C(m-p,n-k)
  reg [19:0] combA;              // C(p,k)
  reg [19:0] combB;              // C(m-p,n-k)
  reg [19:0] comb_den;           // C(m,n)

  reg [7:0]  cycle_cnt;

  // LUT for combinational C(n,k) with n<=16
  function automatic [19:0] comb16;
    input [4:0] n_in;
    input [4:0] k_in;
    reg   [4:0] n;
    reg   [4:0] k;
    begin
      n = n_in;
      k = k_in;
      if (k > n) begin
        comb16 = 20'd0;
      end else begin
        if (k > (n - k)) k = n - k;
        case (n)
          5'd0:  comb16 = (k==0) ? 20'd1 : 20'd0;
          5'd1:  comb16 = (k==0 || k==1) ? 20'd1 : 20'd0;
          5'd2:  begin
                   case (k)
                     0: comb16 = 20'd1;
                     1: comb16 = 20'd2;
                     2: comb16 = 20'd1;
                     default: comb16 = 20'd0;
                   endcase
                 end
          5'd3:  begin
                   case (k)
                     0: comb16 = 20'd1;
                     1: comb16 = 20'd3;
                     2: comb16 = 20'd3;
                     3: comb16 = 20'd1;
                     default: comb16 = 20'd0;
                   endcase
                 end
          5'd4:  begin
                   case (k)
                     0: comb16 = 20'd1;
                     1: comb16 = 20'd4;
                     2: comb16 = 20'd6;
                     3: comb16 = 20'd4;
                     4: comb16 = 20'd1;
                     default: comb16 = 20'd0;
                   endcase
                 end
          5'd5:  begin
                   case (k)
                     0: comb16 = 20'd1;
                     1: comb16 = 20'd5;
                     2: comb16 = 20'd10;
                     3: comb16 = 20'd10;
                     4: comb16 = 20'd5;
                     5: comb16 = 20'd1;
                     default: comb16 = 20'd0;
                   endcase
                 end
          5'd6:  begin
                   case (k)
                     0: comb16 = 20'd1;
                     1: comb16 = 20'd6;
                     2: comb16 = 20'd15;
                     3: comb16 = 20'd20;
                     4: comb16 = 20'd15;
                     5: comb16 = 20'd6;
                     6: comb16 = 20'd1;
                     default: comb16 = 20'd0;
                   endcase
                 end
          5'd7:  begin
                   case (k)
                     0: comb16 = 20'd1;
                     1: comb16 = 20'd7;
                     2: comb16 = 20'd21;
                     3: comb16 = 20'd35;
                     4: comb16 = 20'd35;
                     5: comb16 = 20'd21;
                     6: comb16 = 20'd7;
                     7: comb16 = 20'd1;
                     default: comb16 = 20'd0;
                   endcase
                 end
          5'd8:  begin
                   case (k)
                     0: comb16 = 20'd1;
                     1: comb16 = 20'd8;
                     2: comb16 = 20'd28;
                     3: comb16 = 20'd56;
                     4: comb16 = 20'd70;
                     5: comb16 = 20'd56;
                     6: comb16 = 20'd28;
                     7: comb16 = 20'd8;
                     8: comb16 = 20'd1;
                     default: comb16 = 20'd0;
                   endcase
                 end
          5'd9:  begin
                   case (k)
                     0: comb16 = 20'd1;
                     1: comb16 = 20'd9;
                     2: comb16 = 20'd36;
                     3: comb16 = 20'd84;
                     4: comb16 = 20'd126;
                     5: comb16 = 20'd126;
                     6: comb16 = 20'd84;
                     7: comb16 = 20'd36;
                     8: comb16 = 20'd9;
                     9: comb16 = 20'd1;
                     default: comb16 = 20'd0;
                   endcase
                 end
          5'd10: begin
                   case (k)
                     0:  comb16 = 20'd1;
                     1:  comb16 = 20'd10;
                     2:  comb16 = 20'd45;
                     3:  comb16 = 20'd120;
                     4:  comb16 = 20'd210;
                     5:  comb16 = 20'd252;
                     6:  comb16 = 20'd210;
                     7:  comb16 = 20'd120;
                     8:  comb16 = 20'd45;
                     9:  comb16 = 20'd10;
                     10: comb16 = 20'd1;
                     default: comb16 = 20'd0;
                   endcase
                 end
          5'd11: begin
                   case (k)
                     0:  comb16 = 20'd1;
                     1:  comb16 = 20'd11;
                     2:  comb16 = 20'd55;
                     3:  comb16 = 20'd165;
                     4:  comb16 = 20'd330;
                     5:  comb16 = 20'd462;
                     6:  comb16 = 20'd462;
                     7:  comb16 = 20'd330;
                     8:  comb16 = 20'd165;
                     9:  comb16 = 20'd55;
                     10: comb16 = 20'd11;
                     11: comb16 = 20'd1;
                     default: comb16 = 20'd0;
                   endcase
                 end
          5'd12: begin
                   case (k)
                     0:  comb16 = 20'd1;
                     1:  comb16 = 20'd12;
                     2:  comb16 = 20'd66;
                     3:  comb16 = 20'd220;
                     4:  comb16 = 20'd495;
                     5:  comb16 = 20'd792;
                     6:  comb16 = 20'd924;
                     7:  comb16 = 20'd792;
                     8:  comb16 = 20'd495;
                     9:  comb16 = 20'd220;
                     10: comb16 = 20'd66;
                     11: comb16 = 20'd12;
                     12: comb16 = 20'd1;
                     default: comb16 = 20'd0;
                   endcase
                 end
          5'd13: begin
                   case (k)
                     0:  comb16 = 20'd1;
                     1:  comb16 = 20'd13;
                     2:  comb16 = 20'd78;
                     3:  comb16 = 20'd286;
                     4:  comb16 = 20'd715;
                     5:  comb16 = 20'd1287;
                     6:  comb16 = 20'd1716;
                     7:  comb16 = 20'd1716;
                     8:  comb16 = 20'd1287;
                     9:  comb16 = 20'd715;
                     10: comb16 = 20'd286;
                     11: comb16 = 20'd78;
                     12: comb16 = 20'd13;
                     13: comb16 = 20'd1;
                     default: comb16 = 20'd0;
                   endcase
                 end
          5'd14: begin
                   case (k)
                     0:  comb16 = 20'd1;
                     1:  comb16 = 20'd14;
                     2:  comb16 = 20'd91;
                     3:  comb16 = 20'd364;
                     4:  comb16 = 20'd1001;
                     5:  comb16 = 20'd2002;
                     6:  comb16 = 20'd3003;
                     7:  comb16 = 20'd3432;
                     8:  comb16 = 20'd3003;
                     9:  comb16 = 20'd2002;
                     10: comb16 = 20'd1001;
                     11: comb16 = 20'd364;
                     12: comb16 = 20'd91;
                     13: comb16 = 20'd14;
                     14: comb16 = 20'd1;
                     default: comb16 = 20'd0;
                   endcase
                 end
          5'd15: begin
                   case (k)
                     0:  comb16 = 20'd1;
                     1:  comb16 = 20'd15;
                     2:  comb16 = 20'd105;
                     3:  comb16 = 20'd455;
                     4:  comb16 = 20'd1365;
                     5:  comb16 = 20'd3003;
                     6:  comb16 = 20'd5005;
                     7:  comb16 = 20'd6435;
                     8:  comb16 = 20'd6435;
                     9:  comb16 = 20'd5005;
                     10: comb16 = 20'd3003;
                     11: comb16 = 20'd1365;
                     12: comb16 = 20'd455;
                     13: comb16 = 20'd105;
                     14: comb16 = 20'd15;
                     15: comb16 = 20'd1;
                     default: comb16 = 20'd0;
                   endcase
                 end
          5'd16: begin
                   case (k)
                     0:  comb16 = 20'd1;
                     1:  comb16 = 20'd16;
                     2:  comb16 = 20'd120;
                     3:  comb16 = 20'd560;
                     4:  comb16 = 20'd1820;
                     5:  comb16 = 20'd4368;
                     6:  comb16 = 20'd8008;
                     7:  comb16 = 20'd11440;
                     8:  comb16 = 20'd12870;
                     9:  comb16 = 20'd11440;
                     10: comb16 = 20'd8008;
                     11: comb16 = 20'd4368;
                     12: comb16 = 20'd1820;
                     13: comb16 = 20'd560;
                     14: comb16 = 20'd120;
                     15: comb16 = 20'd16;
                     16: comb16 = 20'd1;
                     default: comb16 = 20'd0;
                   endcase
                 end
          default: comb16 = 20'd0;
        endcase
      end
    end
  endfunction

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = CALC_COMB;
      end
      CALC_COMB: begin
        // Move to DIVIDE once summation completed
        if (k_cur > k_max_r) next_state = DIVIDE;
      end
      DIVIDE: begin
        // Simple fixed latency division stage; advance to DONE late in schedule
        if (cycle_cnt >= 8'd18) next_state = DONE;
      end
      DONE: begin
        // Go back to IDLE after one cycle of done
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= IDLE;
      probability   <= 32'd0;
      done          <= 1'b0;
      m_r           <= 5'd0;
      n_r           <= 4'd0;
      t_r           <= 4'd0;
      p_r           <= 5'd0;
      k_min_r       <= 5'd0;
      k_max_r       <= 5'd0;
      k_cur         <= 5'd0;
      numerator_sum <= 40'd0;
      combA         <= 20'd0;
      combB         <= 20'd0;
      comb_den      <= 20'd1;
      cycle_cnt     <= 8'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done        <= 1'b0;
          probability <= 32'd0;
          cycle_cnt   <= 8'd0;
          if (start) begin
            // Latch inputs
            m_r <= m;
            n_r <= n;
            t_r <= t;
            p_r <= p;

            // Compute k_min = ceil(p / t)
            if (t != 0) begin
              k_min_r <= (p + t - 1) / t;
            end else begin
              k_min_r <= 5'd0;
            end

            // Set k_max = min(n, p)
            if (n <= p[3:0]) k_max_r <= n;
            else             k_max_r <= p[4:0];

            // Initialize summation
            numerator_sum <= 40'd0;
            k_cur         <= 5'd0; // will be set in CALC_COMB when k_min valid

            // Precompute denominator C(m,n)
            comb_den <= comb16(m, n);
          end
        end

        CALC_COMB: begin
          cycle_cnt <= cycle_cnt + 8'd1;

          // Ensure k_cur starts from k_min_r on first cycle in this state
          if (cycle_cnt == 8'd0) begin
            k_cur <= k_min_r;
          end else if (k_cur <= k_max_r) begin
            // Compute terms for current k_cur
            combA <= comb16(p_r,   k_cur);
            combB <= comb16(m_r - p_r, n_r - k_cur[3:0]);

            // Accumulate product into numerator_sum
            numerator_sum <= numerator_sum + (combA * combB);

            // Increment k
            k_cur <= k_cur + 5'd1;
          end
        end

        DIVIDE: begin
          // Maintain cycle count to meet overall latency requirement
          cycle_cnt <= cycle_cnt + 8'd1;

          // Perform division once (combinational) into Q16.16 when entering DIVIDE
          // Use a simple scaled divide: probability = (numerator_sum << 16) / comb_den
          // Protect against divide-by-zero
          if (cycle_cnt == 8'd0) begin
            if (comb_den != 0) begin
              probability <= (numerator_sum << 16) / comb_den;
            end else begin
              probability <= 32'd0;
            end
          end
        end

        DONE: begin
          // Assert done; then next_state will go to IDLE
          done      <= 1'b1;
          cycle_cnt <= 8'd0;
        end

        default: begin
          // Should not occur; safe defaults
          done        <= 1'b0;
          probability <= 32'd0;
        end
      endcase
    end
  end

endmodule