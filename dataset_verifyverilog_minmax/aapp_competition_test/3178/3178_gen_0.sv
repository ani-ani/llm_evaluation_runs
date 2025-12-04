module city_decoration (
  input clk,
  input rst_n,
  input start,
  input [5:0][1:0] edges,  // 6 roads (0: unused, 1-4: [a,b] with a<b<4)
  input [2:0] m_actual,     // actual used roads (1..6)
  output reg [4:0] min_cost,// min cost (0..12) or -1 (5-bit signed)
  output reg done            // pulse high when result is ready
);
  // Local constants
  localparam IDLE = 2'b00;
  localparam INIT = 2'b01;
  localparam ITER = 2'b10;

  // Latched inputs
  reg [5:0][1:0] e_latched;
  reg [2:0] m_latched;

  // FSM state
  reg [1:0] state;

  // Iteration counter over 3^6 combinations
  reg [12:0] combo; // 0..728
  wire [12:0] max_combo = 13'd729; // 3^6

  // Decode edges per cycle
  reg [3:0] active_cnt;      // number of valid edges
  reg [3:0] e_nodes [5:0];   // per edge: {a,b} packed in 4 bits (0..3 each)
  reg [5:0] e_valid;         // per edge valid flag
  wire [3:0] a0 = edges[0][1:0]; // packed (a,b) for edge0
  wire [3:0] a1 = edges[1][1:0];
  wire [3:0] a2 = edges[2][1:0];
  wire [3:0] a3 = edges[3][1:0];
  wire [3:0] a4 = edges[4][1:0];
  wire [3:0] a5 = edges[5][1:0];

  // Current combination (0..2) for each of 6 edges
  wire [1:0] comb [5:0];
  // Base-3 decode: combo = d0 + 3*d1 + 9*d2 + 27*d3 + 81*d4 + 243*d5
  assign comb[0] = combo % 3'd3;
  assign comb[1] = (combo / 3'd3) % 3'd3;
  assign comb[2] = (combo / 3'd9) % 3'd3;
  assign comb[3] = (combo / 3'd27) % 3'd3;
  assign comb[4] = (combo / 3'd81) % 3'd3;
  assign comb[5] = (combo / 3'd243) % 3'd3;

  // Current cost for this combination
  wire [3:0] comb_cost = comb[0] + comb[1] + comb[2] + comb[3] + comb[4] + comb[5]; // 0..18 fits 5 bits

  // Checks per node (adjacent roads constraint and degree parity)
  // Adjacent roads constraint: For each node, if degree=2, let its two incident edges have decorations a,b; then (a+b) mod 3 != 1.
  // Cycle constraint: For the 4-node cycle (0-1-2-3-0), if all four edges exist, the sum of their decorations must be odd.
  // We also require every node to have even degree (ensures only the 4-cycle is a possible cycle in this 4-node graph with no parallel edges).

  // Track degrees and decorations per node for this combination
  reg [2:0] deg0, deg1, deg2, deg3;  // 0..6
  reg [2:0] dec0_sum, dec1_sum, dec2_sum, dec3_sum; // sum of decorations per node (0..12)
  reg odd_sum_0123; // (dec0+dec1+dec2+dec3) mod 2

  // Combinational evaluation of this combination (based on comb[] and latched edges)
  reg valid; // is current combination valid?

  // Per-node pair decoration tracking for the 4-cycle edges if they exist
  // Node 0-1 edge index, 1-2, 2-3, 3-0
  reg [2:0] dec_01, dec_12, dec_23, dec_30;  // decorations 0..2 or 3 if edge missing
  reg has_01, has_12, has_23, has_30;

  // FSM
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      min_cost <= 5'b00000; // undefined, but 0 is a valid cost; set properly after init
      e_latched <= '0;
      m_latched <= '0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            e_latched <= edges;
            m_latched <= m_actual;
            state <= INIT;
          end
        end
        INIT: begin
          // Initialization for search
          combo <= 13'd0;
          min_cost <= 5'b10000; // -5 as starting sentinel, within -16..15
          state <= ITER;
        end
        ITER: begin
          // Evaluate current combination
          if (valid) begin
            if (comb_cost < min_cost) begin
              min_cost <= comb_cost;
            end
          end
          // Next combination
          combo <= combo + 1;
          if (combo + 1 >= max_combo) begin
            done <= 1'b1;
            state <= IDLE;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end

  // Decode latched edges to node pairs, count valid edges
  always @(*) begin
    // Default
    active_cnt = 4'd0;
    for (int i = 0; i < 6; i++) begin
      e_valid[i] = 1'b0;
      e_nodes[i] = 4'd0;
    end
    for (int i = 0; i < 6; i++) begin
      if (e_latched[i] != 2'd0) begin
        e_valid[i] = 1'b1;
        e_nodes[i] = {e_latched[i][1], e_latched[i][0]}; // {a,b}
        active_cnt = active_cnt + 1;
      end
    end
  end

  // For current combination, compute per-node degrees and decoration sums
  always @(*) begin
    deg0 = 3'd0; deg1 = 3'd0; deg2 = 3'd0; deg3 = 3'd0;
    dec0_sum = 3'd0; dec1_sum = 3'd0; dec2_sum = 3'd0; dec3_sum = 3'd0;
    // Defaults for cycle checks
    has_01 = 1'b0; has_12 = 1'b0; has_23 = 1'b0; has_30 = 1'b0;
    dec_01 = 3'd0; dec_12 = 3'd0; dec_23 = 3'd0; dec_30 = 3'd0;
    // Scan edges
    for (int i = 0; i < 6; i++) begin
      if (e_valid[i]) begin
        {int a; int b; int d;} = 0; // local vars
        a = e_nodes[i][3:2];
        b = e_nodes[i][1:0];
        d = comb[i];
        case (a)
          0: begin deg0 = deg0 + 1; dec0_sum = dec0_sum + d; end
          1: begin deg1 = deg1 + 1; dec1_sum = dec1_sum + d; end
          2: begin deg2 = deg2 + 1; dec2_sum = dec2_sum + d; end
          3: begin deg3 = deg3 + 1; dec3_sum = dec3_sum + d; end
        endcase
        case (b)
          0: begin deg0 = deg0 + 1; dec0_sum = dec0_sum + d; end
          1: begin deg1 = deg1 + 1; dec1_sum = dec1_sum + d; end
          2: begin deg2 = deg2 + 1; dec2_sum = dec2_sum + d; end
          3: begin deg3 = deg3 + 1; dec3_sum = dec3_sum + d; end
        endcase
        // Track 4-cycle edges if present
        if ((a==0 && b==1) || (a==1 && b==0)) begin has_01 = 1'b1; dec_01 = d; end
        if ((a==1 && b==2) || (a==2 && b==1)) begin has_12 = 1'b1; dec_12 = d; end
        if ((a==2 && b==3) || (a==3 && b==2)) begin has_23 = 1'b1; dec_23 = d; end
        if ((a==3 && b==0) || (a==0 && b==3)) begin has_30 = 1'b1; dec_30 = d; end
      end
    end
  end

  // Overall odd sum check for the 4-cycle
  always @(*) begin
    odd_sum_0123 = (dec0_sum + dec1_sum + dec2_sum + dec3_sum) & 1'b1;
  end

  // Evaluate constraints for this combination
  always @(*) begin
    bit adj_ok;
    bit deg_even;
    bit cycle_ok;
    bit m_ok;

    adj_ok = 1'b1;
    // Adjacent roads constraint per node: if degree==2, (a+b) mod 3 != 1
    if (deg0 == 3'd2) adj_ok = adj_ok & ((dec0_sum % 3) != 3'd1);
    if (deg1 == 3'd2) adj_ok = adj_ok & ((dec1_sum % 3) != 3'd1);
    if (deg2 == 3'd2) adj_ok = adj_ok & ((dec2_sum % 3) != 3'd1);
    if (deg3 == 3'd2) adj_ok = adj_ok & ((dec3_sum % 3) != 3'd1);

    // Degree constraint: every node must have even degree (to avoid odd cycles not part of the 4-cycle)
    deg_even = (deg0[0] == 1'b0) && (deg1[0] == 1'b0) && (deg2[0] == 1'b0) && (deg3[0] == 1'b0);

    // Cycle sum constraint: If the 4-node cycle edges all exist, their sum must be odd.
    if (has_01 && has_12 && has_23 && has_30) begin
      cycle_ok = (({2'b0, dec_01} + {2'b0, dec_12} + {2'b0, dec_23} + {2'b0, dec_30}) & 1'b1) == 1'b1;
    end else begin
      // If the 4-cycle is not fully present, no explicit cycle-sum constraint applies
      cycle_ok = 1'b1;
    end

    // m_actual check (active edges must match provided count)
    m_ok = (active_cnt == m_latched);

    valid = adj_ok && deg_even && cycle_ok && m_ok;
  end
endmodule
