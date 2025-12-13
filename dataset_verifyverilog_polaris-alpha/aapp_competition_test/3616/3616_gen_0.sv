module allergen_test_optimizer(
  input clk,
  input rst_n,
  input start,
  input [2:0] k,
  input [2:0] D1,
  input [2:0] D2,
  input [2:0] D3,
  input [2:0] D4,
  output reg done,
  output reg [4:0] T
);

  // Internal registers
  reg [4:0] T_stage1;
  reg [4:0] T_stage2;
  reg [2:0] k_reg1, k_reg2;
  reg [2:0] D1_reg1, D2_reg1, D3_reg1, D4_reg1;
  reg stage1_valid, stage2_valid;

  // Combinational wires for max durations and pair sums
  wire [2:0] D_max;
  wire [3:0] sum12, sum13, sum14, sum23, sum24, sum34;
  wire [4:0] pair_max;

  // Max of D1..D4 limited by k
  function [2:0] max4;
    input [2:0] a,b,c,d;
    reg [2:0] m1,m2;
    begin
      m1 = (a>b)?a:b;
      m2 = (c>d)?c:d;
      max4 = (m1>m2)?m1:m2;
    end
  endfunction

  assign D_max = (k == 3'd1) ? D1 :
                 (k == 3'd2) ? ((D1 > D2) ? D1 : D2) :
                 (k == 3'd3) ? max4(D1,D2,D3,3'd0) :
                 max4(D1,D2,D3,D4);

  // Pair sums (only relevant pairs by k will be effectively used)
  assign sum12 = D1 + D2;
  assign sum13 = D1 + D3;
  assign sum14 = D1 + D4;
  assign sum23 = D2 + D3;
  assign sum24 = D2 + D4;
  assign sum34 = D3 + D4;

  // Compute maximum pair sum used as lower bound to guarantee disjoint windows
  // (this over-satisfies the ">=1 unique day" constraint but is simple and parallel)
  assign pair_max = (k <= 3'd1) ? {2'b00, D_max} :
                    (k == 3'd2) ? {1'b0, sum12} :
                    (k == 3'd3) ? (
                       (sum12 >= sum13 && sum12 >= sum23) ? {1'b0,sum12} :
                       (sum13 >= sum12 && sum13 >= sum23) ? {1'b0,sum13} :
                                                            {1'b0,sum23}
                    ) :
                    (
                      (sum12 >= sum13 && sum12 >= sum14 && sum12 >= sum23 && sum12 >= sum24 && sum12 >= sum34) ? {1'b0,sum12} :
                      (sum13 >= sum12 && sum13 >= sum14 && sum13 >= sum23 && sum13 >= sum24 && sum13 >= sum34) ? {1'b0,sum13} :
                      (sum14 >= sum12 && sum14 >= sum13 && sum14 >= sum23 && sum14 >= sum24 && sum14 >= sum34) ? {1'b0,sum14} :
                      (sum23 >= sum12 && sum23 >= sum13 && sum23 >= sum14 && sum23 >= sum24 && sum23 >= sum34) ? {1'b0,sum23} :
                      (sum24 >= sum12 && sum24 >= sum13 && sum24 >= sum14 && sum24 >= sum23 && sum24 >= sum34) ? {1'b0,sum24} :
                                                                                                          {1'b0,sum34}
                    );

  // Simple minimal T candidate: maximum of D_max and pair_max, and at least k
  // (ensures capacity for unique days; example k=3, D=2 -> T=5)
  function [4:0] max5;
    input [4:0] a,b;
    begin
      max5 = (a>b)?a:b;
    end
  endfunction

  // Sequential pipeline: 3-cycle latency
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset state
      T <= 5'd0;
      done <= 1'b0;
      T_stage1 <= 5'd0;
      T_stage2 <= 5'd0;
      k_reg1 <= 3'd0;
      k_reg2 <= 3'd0;
      D1_reg1 <= 3'd0;
      D2_reg1 <= 3'd0;
      D3_reg1 <= 3'd0;
      D4_reg1 <= 3'd0;
      stage1_valid <= 1'b0;
      stage2_valid <= 1'b0;
    end else begin
      // Default
      done <= 1'b0;

      // Stage 1: latch inputs and pair-check related values
      if (start) begin
        k_reg1 <= k;
        D1_reg1 <= D1;
        D2_reg1 <= D2;
        D3_reg1 <= D3;
        D4_reg1 <= D4;
        // Use pair_max as result of parallel pair overlap analysis bound
        T_stage1 <= pair_max;
        stage1_valid <= 1'b1;
      end else begin
        stage1_valid <= 1'b0;
      end

      // Stage 2: compute minimal T candidate based on Stage 1 result
      if (stage1_valid) begin
        // Ensure T is at least big enough for all durations and k unique slots
        // Use D_max and k with Stage1 pair_max
        // Recompute D_max from latched values for robustness
        // (small combinational cost, still within this stage)
        begin : stage2_calc
          reg [2:0] Dmax_s2;
          reg [4:0] base_T;
          reg [4:0] Tk;
          reg [4:0] temp;
          reg [2:0] a,b,c,d;
          a = D1_reg1;
          b = D2_reg1;
          c = (k_reg1 >= 3'd3) ? D3_reg1 : 3'd0;
          d = (k_reg1 == 3'd4) ? D4_reg1 : 3'd0;

          // local max4
          begin : local_max
            reg [2:0] m1,m2;
            m1 = (a>b)?a:b;
            m2 = (c>d)?c:d;
            Dmax_s2 = (m1>m2)?m1:m2;
          end

          base_T = max5(T_stage1, {2'b00,Dmax_s2});
          Tk = {2'b00,k_reg1};
          temp = max5(base_T, Tk);
          // Guarantee at least 1 day
          T_stage2 <= (temp == 5'd0) ? 5'd1 : temp;
        end
        k_reg2 <= k_reg1;
        stage2_valid <= 1'b1;
      end else begin
        stage2_valid <= 1'b0;
      end

      // Stage 3: register final result and assert done
      if (stage2_valid) begin
        T <= T_stage2;
        done <= 1'b1;
      end
    end
  end

endmodule