module phaser_max_hits (
  input reg clk,
  input reg rst_n,
  input reg start,
  input reg [3:0] room_count,
  input reg [9:0] length,
  input reg [14:0][39:0] rooms_array,
  output reg [3:0] max_hits,
  output reg done
);

  // Constants and types
  localparam W = 16;             // Q8.8 fixed point width
  localparam FRAC = 8;
  typedef logic signed [W-1:0] sQ88;

  // Precomputed cos/sin in Q8.8 for 16 angles (0..337.5 deg, step 22.5)
  localparam sQ88 COS [0:15] = '{
    $signed(16'h0100), // 0 deg   : 1.000000 -> 256
    $signed(16'h0F6A), // 22.5 deg: 0.923880 -> ~236
    $signed(16'h0B60), // 45 deg  : 0.707107 -> ~182
    $signed(16'h068B), // 67.5 deg: 0.382683 -> 104.3 -> 104
    $signed(16'h0000), // 90 deg  : 0.000000
    $signed(16'hF975), // 112.5   : -0.382683 -> -104
    $signed(16'hF4A0), // 135     : -0.707107 -> -182
    $signed(16'hF096), // 157.5   : -0.923880 -> -236
    $signed(16'hF000), // 180     : -1.000000 -> -256
    $signed(16'hF096), // 202.5   : -0.923880 -> -236
    $signed(16'hF4A0), // 225     : -0.707107 -> -182
    $signed(16'hF975), // 247.5   : -0.382683 -> -104
    $signed(16'h0000), // 270     : -0.000000
    $signed(16'h068B), // 292.5   :  0.382683 -> 104
    $signed(16'h0B60), // 315     :  0.707107 -> 182
    $signed(16'h0F6A), // 337.5   :  0.923880 -> 236
    $signed(16'h0100)  // 360     :  1.000000 -> 256
  };
  localparam sQ88 SIN [0:15] = '{
    $signed(16'h0000), // 0 deg  : 0.000000
    $signed(16'h068B), // 22.5   : 0.382683 -> 104
    $signed(16'h0B60), // 45     : 0.707107 -> 182
    $signed(16'h0F6A), // 67.5   : 0.923880 -> 236
    $signed(16'h0100), // 90     : 1.000000 -> 256
    $signed(16'h0F6A), // 112.5  : 0.923880 -> 236
    $signed(16'h0B60), // 135    : 0.707107 -> 182
    $signed(16'h068B), // 157.5  : 0.382683 -> 104
    $signed(16'h0000), // 180    : 0.000000
    $signed(16'hF975), // 202.5  : -0.382683 -> -104
    $signed(16'hF4A0), // 225    : -0.707107 -> -182
    $signed(16'hF096), // 247.5  : -0.923880 -> -236
    $signed(16'hF000), // 270    : -1.000000 -> -256
    $signed(16'hF096), // 292.5  : -0.923880 -> -236
    $signed(16'hF4A0), // 315    : -0.707107 -> -182
    $signed(16'hF975)  // 337.5  : -0.382683 -> -104
  };

  // State machine
  typedef enum logic [2:0] { IDLE = 3'd0, PREP = 3'd1, ANGLE = 3'd2, ROOM = 3'd3, FINAL = 3'd4 } state_t;
  state_t state, next_state;

  // Iteration/control signals
  logic [4:0] angle_i;              // 0..15
  logic [3:0] room_i;               // 0..14
  logic [3:0] room_count_r;         // registered room_count
  logic [3:0] max_hits_r;
  logic [3:0] max_hits_next;
  logic [3:0] hit_count_r;          // per angle
  logic [3:0] hit_count_next;
  logic [9:0] length_r;
  logic [9:0] end_x, end_y;         // beam endpoint integers
  logic [15:0] dx_s1, dy_s1;        // signed delta * 1 (scaled) in Q8.8
  logic [31:0] dx_s1_ext, dy_s1_ext;
  logic signed [31:0] num_x0, num_y0, num_x1, num_y1; // numerators for t0/t1
  logic signed [31:0] num_x0_out, num_y0_out, num_x1_out, num_y1_out;
  logic signed [31:0] den_x, den_y; // denominators for t0/t1
  int t0, t1;                       // 0..1 inclusive
  logic finished_angle;
  logic [39:0] room;
  logic [9:0] x1, y1, x2, y2;
  logic [9:0] rminx, rmaxx, rminy, rmaxy;

  // Packed sin/cos for current angle
  sQ88 cosQ, sinQ;

  // Helper functions (min/max for ints)
  function int ismin (int a, int b); return (a < b) ? a : b; endfunction
  function int ismax (int a, int b); return (a > b) ? a : b; endfunction

  // Angle sin/cos lookup (combinational)
  assign cosQ = COS[angle_i];
  assign sinQ = SIN[angle_i];

  // Compute endpoint in integers: (l*cos>>8), (l*sin>>8)
  always_comb begin
    dx_s1 = ($signed(length_r) * cosQ) >>> 8; // Q8.8 * 10-bit -> Q8.8 >> 8 -> 10-bit-ish
    dy_s1 = ($signed(length_r) * sinQ) >>> 8;
    end_x = dx_s1[9:0];  // take low 10 bits (already scaled)
    end_y = dy_s1[9:0];
  end

  // Pack room for readability
  always_comb begin
    room = rooms_array[room_i];
    {x1, y1, x2, y2} = room;
    rminx = (x1 < x2) ? x1 : x2;
    rmaxx = (x1 < x2) ? x2 : x1;
    rminy = (y1 < y2) ? y1 : y2;
    rmaxy = (y1 < y2) ? y2 : y1;
  end

  // Line-AABB intersection (strict interior hit: Liang-Barsky with t in (0,1))
  always_comb begin
    // Signed numerators for t0/t1 at box bounds (Q8.8 scaled by 1)
    dx_s1_ext = $signed({1'b0, dx_s1});
    dy_s1_ext = $signed({1'b0, dy_s1});

    num_x0 = -$signed({1'b0, rminx}) << 8;  // -minx * 256
    num_x1 = -$signed({1'b0, rmaxx}) << 8;  // -maxx * 256
    num_y0 = -$signed({1'b0, rminy}) << 8;  // -miny * 256
    num_y1 = -$signed({1'b0, rmaxy}) << 8;  // -maxy * 256

    den_x = dx_s1_ext;
    den_y = dy_s1_ext;

    // Convert to t0,t1 using 0.8 fixed-point numerators (Q8.8/256), compare to 1.0 = 256
    if (den_x >= 0) begin
      num_x0_out = num_x0;   // t = num / den
      num_x1_out = num_x1;
    end else begin
      num_x0_out = num_x1;
      num_x1_out = num_x0;
      den_x = -den_x;
    end

    if (den_y >= 0) begin
      num_y0_out = num_y0;
      num_y1_out = num_y1;
    end else begin
      num_y0_out = num_y1;
      num_y1_out = num_y0;
      den_y = -den_y;
    end

    // t0 = max of entering parameters (strict interior requires >= 0)
    t0 = 0;
    if ((den_x != 0) && (num_x0_out > 0)) t0 = ismax(t0, num_x0_out[15:8]); // t in 0..255
    if ((den_y != 0) && (num_y0_out > 0)) t0 = ismax(t0, num_y0_out[15:8]);

    // t1 = min of exiting parameters (strict interior requires <= 255)
    t1 = 255;
    if ((den_x != 0) && (num_x1_out < 0)) t1 = ismin(t1, num_x1_out[15:8]);
    if ((den_y != 0) && (num_y1_out < 0)) t1 = ismin(t1, num_y1_out[15:8]);

    // t0 < t1 ensures intersection in the open interval (0,1)
  end

  // Hit decision
  logic hit;
  assign hit = (t0 < t1);

  // State register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else        state <= next_state;
  end

  // Output registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      max_hits_r <= 4'd0;
      hit_count_r <= 4'd0;
      room_count_r <= 4'd0;
      length_r <= 10'd0;
      angle_i <= 5'd0;
      room_i <= 4'd0;
      done <= 1'b0;
    end else begin
      case (next_state)
        IDLE: begin
          max_hits_r <= 4'd0;
          hit_count_r <= 4'd0;
          room_count_r <= room_count;
          length_r <= length;
          angle_i <= 5'd0;
          room_i <= 4'd0;
          done <= 1'b1; // idle is done
        end
        PREP: begin
          // latched for the burst
          room_count_r <= room_count_r;
          length_r <= length_r;
          done <= 1'b0;
          max_hits_r <= max_hits_r; // will be updated in FINAL
          hit_count_r <= 4'd0;
          angle_i <= 5'd0;
          room_i <= 4'd0;
        end
        ANGLE: begin
          hit_count_r <= hit_count_next; // at start of each angle, may be 0 or 0..N
          // keep room_count_r, length_r constant across angles
        end
        ROOM: begin
          room_i <= room_i + 1'b1;
        end
        FINAL: begin
          max_hits_r <= max_hits_next;
          done <= 1'b1;
        end
      endcase
    end
  end

  // Next-state logic
  always_comb begin
    next_state = state;
    hit_count_next = hit_count_r;
    max_hits_next = max_hits_r;
    finished_angle = 1'b0;

    case (state)
      IDLE: begin
        if (start) next_state = PREP;
        else       next_state = IDLE;
      end
      PREP: begin
        // one cycle to set up and start first angle
        next_state = ANGLE;
      end
      ANGLE: begin
        // entering an angle; start room scan
        if (room_count_r == 0) begin
          // No rooms: this angle contributes 0 hits; update max and move on
          max_hits_next = (hit_count_r > max_hits_r) ? hit_count_r : max_hits_r;
          if (angle_i == 15) begin
            next_state = FINAL;
          end else begin
            next_state = ANGLE;
          end
          finished_angle = 1'b1; // will increment angle_i
        end else begin
          next_state = ROOM;
        end
      end
      ROOM: begin
        if (room_i + 1'b1 == room_count_r) begin
          finished_angle = 1'b1;
          next_state = ANGLE;
        end else begin
          next_state = ROOM;
        end
      end
      FINAL: begin
        next_state = IDLE; // await next start
      end
      default: next_state = IDLE;
    endcase
  end

  // Incrementation of iterators and per-angle accumulation
  always_ff @(posedge clk) begin
    if (state == IDLE) begin
      angle_i <= 5'd0;
      room_i <= 4'd0;
    end else if (next_state == ANGLE) begin
      if (finished_angle) begin
        angle_i <= angle_i + 1'b1;
        room_i <= 4'd0;
        hit_count_next <= 4'd0; // reset for next angle
      end
    end else if (next_state == ROOM) begin
      room_i <= room_i + 1'b1;
      hit_count_next <= hit_count_r + (hit ? 1'b1 : 1'b0);
    end else if (next_state == PREP) begin
      // initialize
      angle_i <= 5'd0;
      room_i <= 4'd0;
      hit_count_next <= 4'd0;
    end
  end

  // Final updates for max_hits and hit_count for non-room path
  always_ff @(posedge clk) begin
    if (state == ANGLE) begin
      if (room_count_r == 0) begin
        if (finished_angle) begin
          max_hits_r <= (hit_count_r > max_hits_r) ? hit_count_r : max_hits_r;
        end
      end
    end
  end

  // Outputs
  assign max_hits = max_hits_r;
endmodule
