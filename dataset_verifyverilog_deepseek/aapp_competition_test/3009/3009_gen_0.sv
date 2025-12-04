module energy_balance_line(
  input clk,
  input rst_n,
  input [2:0] n,
  input [6:0] x_i [0:7],
  input [6:0] y_i [0:7],
  input [12:0] e_i [0:7],
  input start,
  output reg [31:0] min_length,
  output reg impossible,
  output reg done
);

  typedef enum logic [2:0] {
    IDLE,
    CALC_TOTAL,
    ITER_SUBSETS,
    CHECK_ENERGY,
    CONVEX_HULL,
    CALC_PERIMETER,
    FINISH
  } state_t;
  
  // Fixed-point parameters
  localparam FP_WIDTH = 32;
  localparam FP_FRAC = 16;

  // Internal registers
  state_t state, next_state;
  reg [7:0] subset;
  reg [12:0] total_energy;
  reg [12:0] subset_sum;
  reg [31:0] tolerance;
  reg [12:0] half_total;
  reg valid_subset;
  reg [3:0] hull_count;
  reg [3:0] sorted_idx [0:7];
  reg [6:0] hull_x [0:7];
  reg [6:0] hull_y [0:7];
  
  // Convex hull working variables
  reg [6:0] work_x [0:7];
  reg [6:0] work_y [0:7];
  
  // Output registers
  reg [31:0] next_min;
  reg next_impossible;
  reg next_done;

  // Temporary calculation registers
  reg [31:0] dx, dy;
  reg [63:0] sq_sum;
  
  // Square root approximation (Q16.16)
  function automatic [31:0] fp_sqrt(input [31:0] num);
    reg [31:0] root;
    reg [31:0] bit;
    reg [31:0] res;
    integer i;
    begin
      res = 0;
      root = 0;
      bit = 32'h4000_0000;  // Start with max bit (16th integer bit)
      
      for (i=0; i<16; i=i+1) begin
        root = res | bit;
        if (root * root <= num) begin
          res = root;
        end
        bit = bit >> 1;
      end
      
      // Fractional part refinement
      for (i=0; i<16; i=i+1) begin
        root = res | (bit);
        if (root * root <= num) begin
          res = root;
        end
        bit = bit >> 1;
      end
      
      fp_sqrt = res;
    end
  endfunction

  // Cross product for convex hull
  function automatic signed [15:0] cross(
    input [6:0] x1, y1, x2, y2, x3, y3
  );
    reg signed [15:0] dx1, dy1, dx2, dy2;
    begin
      dx1 = x2 - x1;
      dy1 = y2 - y1;
      dx2 = x3 - x2;
      dy2 = y3 - y2;
      cross = (dx1 * dy2) - (dx2 * dy1);
    end
  endfunction

  // Fixed-point multiplication
  function automatic [31:0] fp_mult(input [31:0] a, input [31:0] b);
    reg [63:0] temp;
    begin
      temp = a * b;
      fp_mult = temp[47:16];  // Q16.16 * Q16.16 → Q32.32 → keep Q16.16
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      min_length <= {16'hFFFF, 16'hFFFF};
      impossible <= 1'b0;
      done <= 1'b0;
      subset <= 8'h0;
      total_energy <= 13'b0;
    end else begin
      state <= next_state;
      min_length <= next_min;
      impossible <= next_impossible;
      done <= next_done;
      
      case (state)
        IDLE: begin
          if (start) begin
            subset <= 8'h0;
            total_energy <= 13'b0;
            next_min <= {16'hFFFF, 16'hFFFF};
          end
        end
        
        CALC_TOTAL: begin
          for (int i=0; i<8; i=i+1)
            if (i < n) total_energy <= total_energy + e_i[i];
        end
        
        ITER_SUBSETS: begin
          subset <= subset + 1;
        end
        
        CHECK_ENERGY: begin
          half_total <= total_energy >>> 1;
          tolerance <= ({19'b0, total_energy} * 19661) >>> 16;  // *0.15 (Q16.16)
        end
        
        CONVEX_HULL: begin
          // Graham's scan implementation
          // ... (convex hull processing steps)
        end
        
        CALC_PERIMETER: begin
          // Calculate and accumulate perimeter
        end
        
        FINISH: begin
          // Final state handling
        end
      endcase
    end
  end

  always_comb begin
    next_state = state;
    next_min = min_length;
    next_impossible = impossible;
    next_done = done;
    
    case (state)
      IDLE: begin
        if (start) next_state = CALC_TOTAL;
      end
      
      CALC_TOTAL: begin
        next_state = ITER_SUBSETS;
      end
      
      ITER_SUBSETS: begin
        if (subset == 255) next_state = FINISH;
        else next_state = CHECK_ENERGY;
      end
      
      CHECK_ENERGY: begin
        valid_subset = 0;
        subset_sum = 0;
        for (int i=0; i<8; i=i+1)
          if (subset[i] && (i < n)) subset_sum += e_i[i];
        
        if ((subset_sum - half_total <= tolerance) && 
            (half_total - subset_sum <= tolerance)) begin
          next_state = CONVEX_HULL;
          valid_subset = 1;
        end else begin
          next_state = ITER_SUBSETS;
        end
      end
      
      CONVEX_HULL: begin
        next_state = CALC_PERIMETER;
      end
      
      CALC_PERIMETER: begin
        // When perimeter calculation completes
        if (/* calculation done */) begin
          if (/* new perimeter < min_length */) begin
            next_min = /* new perimeter */;
          end
          next_state = ITER_SUBSETS;
        end
      end
      
      FINISH: begin
        next_done = 1'b1;
        if (min_length == {16'hFFFF, 16'hFFFF})
          next_impossible = 1'b1;
      end
    endcase
    
    if (!rst_n) begin
      next_state = IDLE;
      next_min = {16'hFFFF, 16'hFFFF};
      next_impossible = 1'b0;
      next_done = 1'b0;
    end
  end

endmodule
