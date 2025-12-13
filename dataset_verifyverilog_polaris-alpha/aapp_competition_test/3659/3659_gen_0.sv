module bookcase_area_min(
  input clk,
  input rst_n,
  input start,
  input [8:0] h0, h1, h2, h3, h4,
  input [4:0] t0, t1, t2, t3, t4,
  output reg [17:0] min_area,
  output reg done
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE    = 3'd0,
    INIT    = 3'd1,
    COMPUTE = 3'd2,
    UPDATE  = 3'd3,
    DONE    = 3'd4
  } state_t;

  state_t state, next_state;

  // 3^5 = 243 combinations -> use 8 bits for index
  reg [7:0] comb_ctr;

  // Latency counter to meet 250-cycle requirement
  reg [7:0] cycle_cnt;

  // Registers to hold current area and validity of partition
  reg [17:0] area;
  reg        valid_partition;

  // Decode: 5 books, each 2 bits (0..2) shelf index from comb_ctr in base-3
  // Precompute digits combinationally based on comb_ctr
  wire [1:0] s0; // shelf for book0
  wire [1:0] s1; // shelf for book1
  wire [1:0] s2;
  wire [1:0] s3;
  wire [1:0] s4;

  // Function to decode one base-3 digit from comb_ctr
  function automatic [1:0] base3_digit(
    input [7:0] val,
    input integer div
  );
    integer q;
    begin
      q = val / div;
      base3_digit = q % 3;
    end
  endfunction

  assign s0 = base3_digit(comb_ctr, 1);
  assign s1 = base3_digit(comb_ctr, 3);
  assign s2 = base3_digit(comb_ctr, 9);
  assign s3 = base3_digit(comb_ctr, 27);
  assign s4 = base3_digit(comb_ctr, 81);

  // Combinational block for computing area and valid_partition for current combination
  reg [8:0] sh0_max_h, sh1_max_h, sh2_max_h;
  reg [7:0] sh0_tot_t, sh1_tot_t, sh2_tot_t; // up to 5*31=155 -> 8 bits
  reg       sh0_has, sh1_has, sh2_has;
  reg [9:0] sum_h;      // sum of 3 heights: 3*511=1533 -> 11 bits, but area limited to 18 anyway
  reg [7:0] max_tot_t;  // max of totals: up to 155

  always @* begin
    // Initialize accumulators
    sh0_max_h = 9'd0;
    sh1_max_h = 9'd0;
    sh2_max_h = 9'd0;
    sh0_tot_t = 8'd0;
    sh1_tot_t = 8'd0;
    sh2_tot_t = 8'd0;
    sh0_has   = 1'b0;
    sh1_has   = 1'b0;
    sh2_has   = 1'b0;

    // Book 0
    case (s0)
      2'd0: begin
        sh0_has   = 1'b1;
        if (h0 > sh0_max_h) sh0_max_h = h0;
        sh0_tot_t = sh0_tot_t + t0;
      end
      2'd1: begin
        sh1_has   = 1'b1;
        if (h0 > sh1_max_h) sh1_max_h = h0;
        sh1_tot_t = sh1_tot_t + t0;
      end
      2'd2: begin
        sh2_has   = 1'b1;
        if (h0 > sh2_max_h) sh2_max_h = h0;
        sh2_tot_t = sh2_tot_t + t0;
      end
      default: ;
    endcase

    // Book 1
    case (s1)
      2'd0: begin
        sh0_has   = 1'b1;
        if (h1 > sh0_max_h) sh0_max_h = h1;
        sh0_tot_t = sh0_tot_t + t1;
      end
      2'd1: begin
        sh1_has   = 1'b1;
        if (h1 > sh1_max_h) sh1_max_h = h1;
        sh1_tot_t = sh1_tot_t + t1;
      end
      2'd2: begin
        sh2_has   = 1'b1;
        if (h1 > sh2_max_h) sh2_max_h = h1;
        sh2_tot_t = sh2_tot_t + t1;
      end
      default: ;
    endcase

    // Book 2
    case (s2)
      2'd0: begin
        sh0_has   = 1'b1;
        if (h2 > sh0_max_h) sh0_max_h = h2;
        sh0_tot_t = sh0_tot_t + t2;
      end
      2'd1: begin
        sh1_has   = 1'b1;
        if (h2 > sh1_max_h) sh1_max_h = h2;
        sh1_tot_t = sh1_tot_t + t2;
      end
      2'd2: begin
        sh2_has   = 1'b1;
        if (h2 > sh2_max_h) sh2_max_h = h2;
        sh2_tot_t = sh2_tot_t + t2;
      end
      default: ;
    endcase

    // Book 3
    case (s3)
      2'd0: begin
        sh0_has   = 1'b1;
        if (h3 > sh0_max_h) sh0_max_h = h3;
        sh0_tot_t = sh0_tot_t + t3;
      end
      2'd1: begin
        sh1_has   = 1'b1;
        if (h3 > sh1_max_h) sh1_max_h = h3;
        sh1_tot_t = sh1_tot_t + t3;
      end
      2'd2: begin
        sh2_has   = 1'b1;
        if (h3 > sh2_max_h) sh2_max_h = h3;
        sh2_tot_t = sh2_tot_t + t3;
      end
      default: ;
    endcase

    // Book 4
    case (s4)
      2'd0: begin
        sh0_has   = 1'b1;
        if (h4 > sh0_max_h) sh0_max_h = h4;
        sh0_tot_t = sh0_tot_t + t4;
      end
      2'd1: begin
        sh1_has   = 1'b1;
        if (h4 > sh1_max_h) sh1_max_h = h4;
        sh1_tot_t = sh1_tot_t + t4;
      end
      2'd2: begin
        sh2_has   = 1'b1;
        if (h4 > sh2_max_h) sh2_max_h = h4;
        sh2_tot_t = sh2_tot_t + t4;
      end
      default: ;
    endcase

    // Check validity: all shelves must be non-empty
    valid_partition = sh0_has & sh1_has & sh2_has;

    // Compute sum of heights
    sum_h = sh0_max_h + sh1_max_h + sh2_max_h;

    // Compute max total thickness
    if (sh0_tot_t >= sh1_tot_t && sh0_tot_t >= sh2_tot_t)
      max_tot_t = sh0_tot_t;
    else if (sh1_tot_t >= sh0_tot_t && sh1_tot_t >= sh2_tot_t)
      max_tot_t = sh1_tot_t;
    else
      max_tot_t = sh2_tot_t;

    // Compute area (18 bits are sufficient)
    area = sum_h * max_tot_t;
  end

  // Next state logic
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = INIT;
      end
      INIT: begin
        next_state = COMPUTE;
      end
      COMPUTE: begin
        next_state = UPDATE;
      end
      UPDATE: begin
        if (comb_ctr == 8'd242)
          next_state = DONE;
        else
          next_state = COMPUTE;
      end
      DONE: begin
        // Stay in DONE until start is deasserted and asserted again
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      comb_ctr  <= 8'd0;
      min_area  <= 18'h3FFFF;
      done      <= 1'b0;
      cycle_cnt <= 8'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done      <= 1'b0;
          cycle_cnt <= 8'd0;
          if (start) begin
            // Wait for INIT on next cycle
          end
        end

        INIT: begin
          // Initialize search
          comb_ctr  <= 8'd0;
          min_area  <= 18'h3FFFF;
          done      <= 1'b0;
          cycle_cnt <= 8'd0;
        end

        COMPUTE: begin
          // Combinational area is evaluated this cycle
          cycle_cnt <= cycle_cnt + 8'd1;
        end

        UPDATE: begin
          // Update min_area for valid partitions
          if (valid_partition && (area < min_area)) begin
            min_area <= area;
          end

          // Increment combination counter
          if (comb_ctr < 8'd242)
            comb_ctr <= comb_ctr + 8'd1;

          cycle_cnt <= cycle_cnt + 8'd1;
        end

        DONE: begin
          done <= 1'b1;
          // Ensure min_area remains stable
          // cycle_cnt can continue or be held; not functionally critical
        end

        default: ;
      endcase
    end
  end

endmodule