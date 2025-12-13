module triangle_area(
  input  logic        clk,
  input  logic        rst_n,
  input  logic [7:0]  a,
  input  logic [7:0]  b,
  input  logic [7:0]  c,
  input  logic        start,
  output logic [15:0] area,
  output logic        valid,
  output logic        error
);

  // FSM states
  typedef enum logic [3:0] {
    S_IDLE   = 4'd0,
    S_VAL    = 4'd1,
    S_MUL1   = 4'd2,
    S_MUL2   = 4'd3,
    S_SQRT0  = 4'd4,
    S_SQRT1  = 4'd5,
    S_SQRT2  = 4'd6,
    S_SQRT3  = 4'd7,
    S_SQRT4  = 4'd8,
    S_OUT    = 4'd9
  } state_t;

  state_t state, next_state;

  // Internal registers
  logic [7:0]  a_r, b_r, c_r;
  logic        start_d;

  // Triangle validity
  logic        tri_valid_comb;
  logic        tri_valid_r;

  // Heron's formula intermediates
  logic [9:0]  sum_abc;           // up to 3*255=765 < 2^10
  logic [8:0]  s;                 // semi-perimeter integer
  logic [9:0]  s_minus_a;
  logic [9:0]  s_minus_b;
  logic [9:0]  s_minus_c;

  // area_sq (Q16.16) in 32 bits
  logic [31:0] area_sq;

  // sqrt pipeline registers
  logic [31:0] sqrt_x;            // input to sqrt
  logic [15:0] sqrt_y0, sqrt_y1, sqrt_y2, sqrt_y3, sqrt_y4; // iterations

  // Output registers
  logic [15:0] area_r;
  logic        valid_r;
  logic        error_r;

  // Combinational triangle validity (using captured a_r,b_r,c_r later)
  assign tri_valid_comb = ((a_r + b_r) > c_r) &&
                          ((a_r + c_r) > b_r) &&
                          ((b_r + c_r) > a_r);

  // Sequential control: state register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= S_IDLE;
      start_d  <= 1'b0;
    end else begin
      state    <= next_state;
      start_d  <= start;
    end
  end

  // Next-state logic (8-cycle pipeline from start pulse)
  always_comb begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start && !start_d) // detect rising edge
          next_state = S_VAL;
      end
      S_VAL:   next_state = S_MUL1;  // cycle 1
      S_MUL1:  next_state = S_MUL2;  // cycle 2
      S_MUL2:  next_state = S_SQRT0; // cycle 3
      S_SQRT0: next_state = S_SQRT1; // cycle 4
      S_SQRT1: next_state = S_SQRT2; // cycle 5
      S_SQRT2: next_state = S_SQRT3; // cycle 6
      S_SQRT3: next_state = S_SQRT4; // cycle 7
      S_SQRT4: next_state = S_OUT;   // cycle 8
      S_OUT:   next_state = S_IDLE;
      default: next_state = S_IDLE;
    endcase
  end

  // Datapath and outputs
  // Capture inputs and compute intermediates through the pipeline.

  // Capture on start edge
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a_r        <= 8'd0;
      b_r        <= 8'd0;
      c_r        <= 8'd0;
      tri_valid_r<= 1'b0;
      sum_abc    <= 10'd0;
      s          <= 9'd0;
      s_minus_a  <= 10'd0;
      s_minus_b  <= 10'd0;
      s_minus_c  <= 10'd0;
      area_sq    <= 32'd0;
      sqrt_x     <= 32'd0;
      sqrt_y0    <= 16'd0;
      sqrt_y1    <= 16'd0;
      sqrt_y2    <= 16'd0;
      sqrt_y3    <= 16'd0;
      sqrt_y4    <= 16'd0;
      area_r     <= 16'h0000;
      valid_r    <= 1'b0;
      error_r    <= 1'b0;
    end else begin
      // Default hold
      valid_r <= 1'b0;
      error_r <= 1'b0;

      case (state)
        S_IDLE: begin
          if (start && !start_d) begin
            a_r <= a;
            b_r <= b;
            c_r <= c;
          end
        end

        // Validation cycle: compute semi-perimeter and validity
        S_VAL: begin
          // compute sum and s using integer arithmetic
          sum_abc     <= a_r + b_r + c_r;        // 10 bits
          s           <= (a_r + b_r + c_r) >> 1; // floor((a+b+c)/2)
          tri_valid_r <= tri_valid_comb;
        end

        // MUL1: compute (s-a), (s-b), (s-c)
        S_MUL1: begin
          s_minus_a <= (s >= a_r) ? (s - a_r) : 10'd0;
          s_minus_b <= (s >= b_r) ? (s - b_r) : 10'd0;
          s_minus_c <= (s >= c_r) ? (s - c_r) : 10'd0;
        end

        // MUL2: compute area_sq in Q16.16 form
        // area_sq = s*(s-a)*(s-b)*(s-c)
        // Use full precision 32-bit integer; treat result as Q16.16.
        S_MUL2: begin
          if (!tri_valid_r) begin
            area_sq <= 32'd0;
          end else begin
            // Multiply in 32-bit domain
            // temp1 = s * (s-a)
            // temp2 = (s-b) * (s-c)
            // area_sq = temp1 * temp2
            logic [19:0] temp1; // 10b * 10b
            logic [19:0] temp2; // 10b * 10b
            temp1   = s * s_minus_a;
            temp2   = s_minus_b * s_minus_c;
            area_sq = temp1 * temp2; // up to 40 bits, but truncated to 32
          end
        end

        // SQRT0: prepare sqrt input and initial guess
        S_SQRT0: begin
          if (!tri_valid_r) begin
            sqrt_x <= 32'd0;
            sqrt_y0 <= 16'd0;
          end else begin
            // Interpret area_sq as Q16.16; we need sqrt in Q8.8
            // Direct integer sqrt on area_sq, then scale: sqrt(Q16.16)=Q8.8
            sqrt_x <= area_sq;
            // Initial guess: simple shift-based (x >> 9) or 1 if small
            if (area_sq == 32'd0)
              sqrt_y0 <= 16'd0;
            else
              sqrt_y0 <= (area_sq[31:16] != 16'd0) ? {8'd0, area_sq[31:24]} : 16'd16;
          end
        end

        // Newton-Raphson iterations (5 cycles total: SQRT0..SQRT4)
        // y_{n+1} = (y_n + x / y_n) / 2

        S_SQRT1: begin
          if (!tri_valid_r || sqrt_y0 == 16'd0) begin
            sqrt_y1 <= 16'd0;
          end else begin
            sqrt_y1 <= (sqrt_y0 + (sqrt_x / sqrt_y0)) >> 1;
          end
        end

        S_SQRT2: begin
          if (!tri_valid_r || sqrt_y1 == 16'd0) begin
            sqrt_y2 <= 16'd0;
          end else begin
            sqrt_y2 <= (sqrt_y1 + (sqrt_x / sqrt_y1)) >> 1;
          end
        end

        S_SQRT3: begin
          if (!tri_valid_r || sqrt_y2 == 16'd0) begin
            sqrt_y3 <= 16'd0;
          end else begin
            sqrt_y3 <= (sqrt_y2 + (sqrt_x / sqrt_y2)) >> 1;
          end
        end

        S_SQRT4: begin
          if (!tri_valid_r || sqrt_y3 == 16'd0) begin
            sqrt_y4 <= 16'd0;
          end else begin
            sqrt_y4 <= (sqrt_y3 + (sqrt_x / sqrt_y3)) >> 1;
          end
        end

        // Output stage: register area, valid, error
        S_OUT: begin
          if (!tri_valid_r) begin
            area_r  <= 16'hFFFF; // -1 in Q8.8
            error_r <= 1'b1;
            valid_r <= 1'b1;
          end else begin
            // sqrt_y4 is Q8.8 approximation (since sqrt_x is Q16.16)
            // Truncate to 8 fractional bits (already in that form)
            area_r  <= sqrt_y4;
            error_r <= 1'b0;
            valid_r <= 1'b1;
          end
        end

        default: ;
      endcase
    end
  end

  // Drive outputs
  assign area  = area_r;
  assign valid = valid_r;
  assign error = error_r;

endmodule
