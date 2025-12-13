module evolution_plans_counter(
  input  [1:0] n,                // expected constant 2'b10 (n=2)
  input  [2:0] m,                // number of types (1-4)
  input  [1:0] gym0_count,       // Pokemon count in gym 0 (0-4)
  input  [1:0] gym1_count,       // Pokemon count in gym 1 (0-4)
  input  [1:0] gym0_types [0:3], // 4 slots for gym0
  input  [1:0] gym1_types [0:3], // 4 slots for gym1
  output [6:0] count             // result modulo 101
);

  // Internal combinational signals
  integer i;

  // Per-type per-gym occurrence counts: occ_tg[type][gym]
  reg [2:0] occ_tg [1:4][0:1];

  // Pattern index (0-4) mapping for each type (1..4)
  reg [2:0] pattern_index [1:4];

  // Group sizes for each pattern (1..4)
  reg [2:0] group_size [1:4];

  // Factorials modulo 101 for k = 0..4 (0!:1,1!:1,2!:2,3!:6,4!:24)
  localparam [6:0] FACT0 = 7'd1;
  localparam [6:0] FACT1 = 7'd1;
  localparam [6:0] FACT2 = 7'd2;
  localparam [6:0] FACT3 = 7'd6;
  localparam [6:0] FACT4 = 7'd24;

  // Result accumulator
  reg [6:0] result_r;

  // Combinational logic
  always @* begin
    // Initialize occurrence counts to zero
    for (i = 1; i <= 4; i = i + 1) begin
      occ_tg[i][0] = 3'd0; // gym0
      occ_tg[i][1] = 3'd0; // gym1
    end

    // Count occurrences in gym0 based on gym0_count
    if (gym0_count > 0) begin
      if (gym0_types[0] >= 2'd1 && gym0_types[0] <= 2'd4)
        occ_tg[gym0_types[0]][0] = occ_tg[gym0_types[0]][0] + 3'd1;
    end
    if (gym0_count > 1) begin
      if (gym0_types[1] >= 2'd1 && gym0_types[1] <= 2'd4)
        occ_tg[gym0_types[1]][0] = occ_tg[gym0_types[1]][0] + 3'd1;
    end
    if (gym0_count > 2) begin
      if (gym0_types[2] >= 2'd1 && gym0_types[2] <= 2'd4)
        occ_tg[gym0_types[2]][0] = occ_tg[gym0_types[2]][0] + 3'd1;
    end
    if (gym0_count > 3) begin
      if (gym0_types[3] >= 2'd1 && gym0_types[3] <= 2'd4)
        occ_tg[gym0_types[3]][0] = occ_tg[gym0_types[3]][0] + 3'd1;
    end

    // Count occurrences in gym1 based on gym1_count
    if (gym1_count > 0) begin
      if (gym1_types[0] >= 2'd1 && gym1_types[0] <= 2'd4)
        occ_tg[gym1_types[0]][1] = occ_tg[gym1_types[0]][1] + 3'd1;
    end
    if (gym1_count > 1) begin
      if (gym1_types[1] >= 2'd1 && gym1_types[1] <= 2'd4)
        occ_tg[gym1_types[1]][1] = occ_tg[gym1_types[1]][1] + 3'd1;
    end
    if (gym1_count > 2) begin
      if (gym1_types[2] >= 2'd1 && gym1_types[2] <= 2'd4)
        occ_tg[gym1_types[2]][1] = occ_tg[gym1_types[2]][1] + 3'd1;
    end
    if (gym1_count > 3) begin
      if (gym1_types[3] >= 2'd1 && gym1_types[3] <= 2'd4)
        occ_tg[gym1_types[3]][1] = occ_tg[gym1_types[3]][1] + 3'd1;
    end

    // Initialize group sizes
    for (i = 1; i <= 4; i = i + 1) begin
      group_size[i] = 3'd0;
    end

    // Compute pattern index and group sizes for types 1..m
    for (i = 1; i <= 4; i = i + 1) begin
      pattern_index[i] = 3'd0;
      if (i <= m) begin
        // Map (occ0, occ1) -> pattern_index in 1..4 based on valid combos of total<=4
        // Unique mapping for all possible (occ0,occ1) with occ0+occ1<=4:
        // p1: (0,0)
        // p2: (1,0),(0,1)
        // p3: (2,0),(1,1),(0,2)
        // p4: (3,0),(2,1),(1,2),(0,3),(4,0),(3,1),(2,2),(1,3),(0,4)
        if (occ_tg[i][0] == 3'd0 && occ_tg[i][1] == 3'd0) begin
          pattern_index[i] = 3'd1;
        end else if ( (occ_tg[i][0] + occ_tg[i][1]) == 3'd1 ) begin
          pattern_index[i] = 3'd2;
        end else if ( (occ_tg[i][0] + occ_tg[i][1]) == 3'd2 ) begin
          pattern_index[i] = 3'd3;
        end else begin
          // sum 3 or 4
          pattern_index[i] = 3'd4;
        end

        // Accumulate group size for this pattern
        if (pattern_index[i] != 3'd0)
          group_size[pattern_index[i]] = group_size[pattern_index[i]] + 3'd1;
      end
    end

    // Compute result as product of (k! mod 101) over all non-empty groups
    result_r = 7'd1;

    // p1
    case (group_size[1])
      3'd0: ;
      3'd1: result_r = (result_r * FACT1) % 7'd101;
      3'd2: result_r = (result_r * FACT2) % 7'd101;
      3'd3: result_r = (result_r * FACT3) % 7'd101;
      default: result_r = (result_r * FACT4) % 7'd101;
    endcase

    // p2
    case (group_size[2])
      3'd0: ;
      3'd1: result_r = (result_r * FACT1) % 7'd101;
      3'd2: result_r = (result_r * FACT2) % 7'd101;
      3'd3: result_r = (result_r * FACT3) % 7'd101;
      default: result_r = (result_r * FACT4) % 7'd101;
    endcase

    // p3
    case (group_size[3])
      3'd0: ;
      3'd1: result_r = (result_r * FACT1) % 7'd101;
      3'd2: result_r = (result_r * FACT2) % 7'd101;
      3'd3: result_r = (result_r * FACT3) % 7'd101;
      default: result_r = (result_r * FACT4) % 7'd101;
    endcase

    // p4
    case (group_size[4])
      3'd0: ;
      3'd1: result_r = (result_r * FACT1) % 7'd101;
      3'd2: result_r = (result_r * FACT2) % 7'd101;
      3'd3: result_r = (result_r * FACT3) % 7'd101;
      default: result_r = (result_r * FACT4) % 7'd101;
    endcase

    // If somehow no valid groups contributed, default stays 1 per initialization
  end

  assign count = result_r;

endmodule