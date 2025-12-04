module game_level_optimizer(
  input clk,
  input rst_n,
  input start,
  input [1:0] x0,
  input [31:0] s0,
  input [31:0] a00, a01, a02, a03,
  input [1:0] x1,
  input [31:0] s1,
  input [31:0] a10, a11, a12, a13,
  input [1:0] x2,
  input [31:0] s2,
  input [31:0] a20, a21, a22, a23,
  output reg [31:0] min_time,
  output reg done
);

  logic [1:0] x0_reg, x1_reg, x2_reg;
  logic [31:0] s0_reg, s1_reg, s2_reg;
  logic [31:0] a00_reg, a01_reg, a02_reg, a03_reg;
  logic [31:0] a10_reg, a11_reg, a12_reg, a13_reg;
  logic [31:0] a20_reg, a21_reg, a22_reg, a23_reg;
  logic compute_flag;
  
  // Permutation times
  logic [31:0] time_012, time_021, time_102, time_120, time_201, time_210;

  // Combinational min calculation
  logic [31:0] min01, min23, min45, min0123;
  
  // State control
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      {x0_reg, x1_reg, x2_reg} <= '0;
      {s0_reg, s1_reg, s2_reg} <= '0;
      {a00_reg, a01_reg, a02_reg, a03_reg} <= '0;
      {a10_reg, a11_reg, a12_reg, a13_reg} <= '0;
      {a20_reg, a21_reg, a22_reg, a23_reg} <= '0;
      compute_flag <= 0;
      done <= 0;
      min_time <= 0;
    end else begin
      done <= 0;
      if (start) begin
        x0_reg <= x0; x1_reg <= x1; x2_reg <= x2;
        s0_reg <= s0; s1_reg <= s1; s2_reg <= s2;
        a00_reg <= a00; a01_reg <= a01; a02_reg <= a02; a03_reg <= a03;
        a10_reg <= a10; a11_reg <= a11; a12_reg <= a12; a13_reg <= a13;
        a20_reg <= a20; a21_reg <= a21; a22_reg <= a22; a23_reg <= a23;
        compute_flag <= 1;
      end else if (compute_flag) begin
        min_time <= (min0123 < min45) ? min0123 : min45;
        done <= 1;
        compute_flag <= 0;
      end
    end
  end

  // Permutation 0-1-2
  always_comb begin
    logic [3:0] used = 4'b1111;
    logic [31:0] t0, t1, t2;
    
    // Level 0
    if (used[x0_reg]) begin
      t0 = s0_reg;
      used[x0_reg] = 0;
    end else begin
      logic [31:0] min_val = {32{1'b1}};
      logic [1:0] min_idx;
      for (int i=0; i<4; i++) begin
        if (used[i]) begin
          logic [31:0] curr = (i==0) ? a00_reg : (i==1) ? a01_reg : (i==2) ? a02_reg : a03_reg;
          if (curr < min_val) begin
            min_val = curr;
            min_idx = i;
          end
        end
      end
      t0 = min_val;
      used[min_idx] = 0;
    end
    
    // Level 1
    if (used[x1_reg]) begin
      t1 = s1_reg;
      used[x1_reg] = 0;
    end else begin
      logic [31:0] min_val = {32{1'b1}};
      logic [1:0] min_idx;
      for (int i=0; i<4; i++) begin
        if (used[i]) begin
          logic [31:0] curr = (i==0) ? a10_reg : (i==1) ? a11_reg : (i==2) ? a12_reg : a13_reg;
          if (curr < min_val) begin
            min_val = curr;
            min_idx = i;
          end
        end
      end
      t1 = min_val;
      used[min_idx] = 0;
    end
    
    // Level 2
    if (used[x2_reg]) begin
      t2 = s2_reg;
    end else begin
      logic [31:0] min_val = {32{1'b1}};
      for (int i=0; i<4; i++) begin
        if (used[i]) begin
          logic [31:0] curr = (i==0) ? a20_reg : (i==1) ? a21_reg : (i==2) ? a22_reg : a23_reg;
          min_val = (curr < min_val) ? curr : min_val;
        end
      end
      t2 = min_val;
    end
    
    time_012 = t0 + t1 + t2;
  end

  // Permutation 0-2-1
  always_comb begin
    logic [3:0] used = 4'b1111;
    logic [31:0] t0, t2, t1;
    
    // Level 0
    if (used[x0_reg]) begin
      t0 = s0_reg;
      used[x0_reg] = 0;
    end else begin
      logic [31:0] min_val = {32{1'b1}};
      logic [1:0] min_idx;
      for (int i=0; i<4; i++) begin
        if (used[i]) begin
          logic [31:0] curr = (i==0) ? a00_reg : (i==1) ? a01_reg : (i==2) ? a02_reg : a03_reg;
          if (curr < min_val) begin
            min_val = curr;
            min_idx = i;
          end
        end
      end
      t0 = min_val;
      used[min_idx] = 0;
    end
    
    // Level 2
    if (used[x2_reg]) begin
      t2 = s2_reg;
      used[x2_reg] = 0;
    end else begin
      logic [31:0] min_val = {32{1'b1}};
      logic [1:0] min_idx;
      for (int i=0; i<4; i++) begin
        if (used[i]) begin
          logic [31:0] curr = (i==0) ? a20_reg : (i==1) ? a21_reg : (i==2) ? a22_reg : a23_reg;
          if (curr < min_val) begin
            min_val = curr;
            min_idx = i;
          end
        end
      end
      t2 = min_val;
      used[min_idx] = 0;
    end
    
    // Level 1
    if (used[x1_reg]) begin
      t1 = s1_reg;
    end else begin
      logic [31:0] min_val = {32{1'b1}};
      for (int i=0; i<4; i++) begin
        if (used[i]) begin
          logic [31:0] curr = (i==0) ? a10_reg : (i==1) ? a11_reg : (i==2) ? a12_reg : a13_reg;
          min_val = (curr < min_val) ? curr : min_val;
        end
      end
      t1 = min_val;
    end
    
    time_021 = t0 + t2 + t1;
  end

  // Permutation 1-0-2
  always_comb begin
    logic [3:0] used = 4'b1111;
    logic [31:0] t1, t0, t2;
    
    // Level 1
    if (used[x1_reg]) begin
      t1 = s1_reg;
      used[x1_reg] = 0;
    end else begin
      logic [31:0] min_val = {32{1'b1}};
      logic [1:0] min_idx;
      for (int i=0; i<4; i++) begin
        if (used[i]) begin
          logic [31:0] curr = (i==0) ? a10_reg : (i==1) ? a11_reg : (i==2) ? a12_reg : a13_reg;
          if (curr < min_val) begin
            min_val = curr;
            min_idx = i;
          end
        end
      end
      t1 = min_val;
      used[min_idx] = 0;
    end
    
    // Level 0
    if (used[x0_reg]) begin
      t0 = s0_reg;
      used[x0_reg] = 0;
    end else begin
      logic [31:0] min_val = {32{1'b1}};
      logic [1:0] min_idx;
      for (int i=0; i<4; i++) begin
        if (used[i]) begin
          logic [31:0] curr = (i==0) ? a00_reg : (i==1) ? a01_reg : (i==2) ? a02_reg : a03_reg;
          if (curr < min_val) begin
            min_val = curr;
            min_idx = i;
          end
        end
      end
      t0 = min_val;
      used[min_idx] = 0;
    end
    
    // Level 2
    if (used[x2_reg]) begin
      t2 = s2_reg;
    end else begin
      logic [31:0] min_val = {32{1'b1}};
      for (int i=0; i<4; i++) begin
        if (used[i]) begin
          logic [31:0] curr = (i==0) ? a20_reg : (i==1) ? a21_reg : (i==2) ? a22_reg : a23_reg;
          min_val = (curr < min_val) ? curr : min_val;
        end
      end
      t2 = min_val;
    end
    
    time_102 = t1 + t0 + t2;
  end

  // Permutation 1-2-0
  always_comb begin
    logic [3:0] used = 4'b1111;
    logic [31:0] t1, t2, t0;
    
    // Level 1
    if (used[x1_reg]) begin
      t1 = s1_reg;
      used[x1_reg] = 0;
    end else begin
      logic [31:0] min_val = {32{1'b1}};
      logic [1:0] min_idx;
      for (int i=0; i<4; i++) begin
        if (used[i]) begin
          logic [31:0] curr = (i==0) ? a10_reg : (i==1) ? a11_reg : (i==2) ? a12_reg : a13_reg;
          if (curr < min_val) begin
            min_val = curr;
            min_idx = i;
          end
        end
      end
      t1 = min_val;
      used[min_idx] = 0;
    end
    
    // Level 2
    if (used[x2_reg]) begin
      t2 = s2_reg;
      used[x2_reg] = 0;
    end else begin
      logic [31:0] min_val = {32{1'b1}};
      logic [1:0] min_idx;
      for (int i=0; i<4; i++) begin
        if (used[i]) begin
          logic [31:0] curr = (i==0) ? a20_reg : (i==1) ? a21_reg : (i==2) ? a22_reg : a23_reg;
          if (curr < min_val) begin
            min_val = curr;
            min_idx = i;
          end
        end
      end
      t2 = min_val;
      used[min_idx] = 0;
    end
    
    // Level 0
    if (used[x0_reg]) begin
      t0 = s0_reg;
    end else begin
      logic [31:0] min_val = {32{1'b1}};
      for (int i=0; i<4; i++) begin
        if (used[i]) begin
          logic [31:0] curr = (i==0) ? a00_reg : (i==1) ? a01_reg : (i==2) ? a02_reg : a03_reg;
          min_val = (curr < min_val) ? curr : min_val;
        end
      end
      t0 = min_val;
    end
    
    time_120 = t1 + t2 + t0;
  end

  // Permutation 2-0-1
  always_comb begin
    logic [3:0] used = 4'b1111;
    logic [31:0] t2, t0, t1;
    
    // Level 2
    if (used[x2_reg]) begin
      t2 = s2_reg;
      used[x2_reg] = 0;
    end else begin
      logic [31:0] min_val = {32{1'b1}};
      logic [1:0] min_idx;
      for (int i=0; i<4; i++) begin
        if (used[i]) begin
          logic [31:0] curr = (i==0) ? a20_reg : (i==1) ? a21_reg : (i==2) ? a22_reg : a23_reg;
          if (curr < min_val) begin
            min_val = curr;
            min_idx = i;
          end
        end
      end
      t2 = min_val;
      used[min_idx] = 0;
    end
    
    // Level 0
    if (used[x0_reg]) begin
      t0 = s0_reg;
      used[x0_reg] = 0;
    end else begin
      logic [31:0] min_val = {32{1'b1}};
      logic [1:0] min_idx;
      for (int i=0; i<4; i++) begin
        if (used[i]) begin
          logic [31:0] curr = (i==0) ? a00_reg : (i==1) ? a01_reg : (i==2) ? a02_reg : a03_reg;
          if (curr < min_val) begin
            min_val = curr;
            min_idx = i;
          end
        end
      end
      t0 = min_val;
      used[min_idx] = 0;
    end
    
    // Level 1
    if (used[x1_reg]) begin
      t1 = s1_reg;
    end else begin
      logic [31:0] min_val = {32{1'b1}};
      for (int i=0; i<4; i++) begin
        if (used[i]) begin
          logic [31:0] curr = (i==0) ? a10_reg : (i==1) ? a11_reg : (i==2) ? a12_reg : a13_reg;
          min_val = (curr < min_val) ? curr : min_val;
        end
      end
      t1 = min_val;
    end
    
    time_201 = t2 + t0 + t1;
  end

  // Permutation 2-1-0
  always_comb begin
    logic [3:0] used = 4'b1111;
    logic [31:0] t2, t1, t0;
    
    // Level 2
    if (used[x2_reg]) begin
      t2 = s2_reg;
      used[x2_reg] = 0;
    end else begin
      logic [31:0] min_val = {32{1'b1}};
      logic [1:0] min_idx;
      for (int i=0; i<4; i++) begin
        if (used[i]) begin
          logic [31:0] curr = (i==0) ? a20_reg : (i==1) ? a21_reg : (i==2) ? a22_reg : a23_reg;
          if (curr < min_val) begin
            min_val = curr;
            min_idx = i;
          end
        end
      end
      t2 = min_val;
      used[min_idx] = 0;
    end
    
    // Level 1
    if (used[x1_reg]) begin
      t1 = s1_reg;
      used[x1_reg] = 0;
    end else begin
      logic [31:0] min_val = {32{1'b1}};
      logic [1:0] min_idx;
      for (int i=0; i<4; i++) begin
        if (used[i]) begin
          logic [31:0] curr = (i==0) ? a10_reg : (i==1) ? a11_reg : (i==2) ? a12_reg : a13_reg;
          if (curr < min_val) begin
            min_val = curr;
            min_idx = i;
          end
        end
      end
      t1 = min_val;
      used[min_idx] = 0;
    end
    
    // Level 0
    if (used[x0_reg]) begin
      t0 = s0_reg;
    end else begin
      logic [31:0] min_val = {32{1'b1}};
      for (int i=0; i<4; i++) begin
        if (used[i]) begin
          logic [31:0] curr = (i==0) ? a00_reg : (i==1) ? a01_reg : (i==2) ? a02_reg : a03_reg;
          min_val = (curr < min_val) ? curr : min_val;
        end
      end
      t0 = min_val;
    end
    
    time_210 = t2 + t1 + t0;
  end

  // Min calculation
  assign min01 = (time_012 < time_021) ? time_012 : time_021;
  assign min23 = (time_102 < time_120) ? time_102 : time_120;
  assign min45 = (time_201 < time_210) ? time_201 : time_210;
  assign min0123 = (min01 < min23) ? min01 : min23;

endmodule