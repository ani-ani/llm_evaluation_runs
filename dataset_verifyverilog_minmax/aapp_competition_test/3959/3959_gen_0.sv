module evolution_plans_counter (
  input reg [1:0] n,
  input reg [2:0] m,
  input reg [1:0] gym0_count,
  input reg [1:0] gym1_count,
  input reg [1:0] gym0_types [0:3],
  input reg [1:0] gym1_types [0:3],
  output reg [6:0] count
);

  always_comb begin
    // Count occurrences of each type in each gym
    int count0 [4];
    int count1 [4];
    int pattern [4];
    int group_counts [25];
    int fact [5];
    int result;
    int i, t, p;

    // Initialize counts to zero
    for (i = 0; i < 4; i++) begin
      count0[i] = 0;
      count1[i] = 0;
    end

    // Count occurrences in gym 0
    for (i = 0; i < gym0_count; i++) begin
      count0[gym0_types[i]]++;
    end

    // Count occurrences in gym 1
    for (i = 0; i < gym1_count; i++) begin
      count1[gym1_types[i]]++;
    end

    // Compute pattern for each type (0..3)
    for (t = 0; t < 4; t++) begin
      pattern[t] = count0[t] * 5 + count1[t]; // 0..24
    end

    // Initialize group_counts
    for (p = 0; p < 25; p++) begin
      group_counts[p] = 0;
    end

    // Count how many types share each pattern (consider only first m types)
    for (t = 0; t < m; t++) begin
      group_counts[pattern[t]]++;
    end

    // Precompute factorials modulo 101 for k = 0..4
    fact[0] = 1 % 101;
    fact[1] = 1 % 101;
    fact[2] = 2 % 101;
    fact[3] = 6 % 101;
    fact[4] = 24 % 101;

    // Compute result as product of factorials of group sizes
    result = 1;
    for (p = 0; p < 25; p++) begin
      if (group_counts[p] > 0) begin
        result = (result * fact[group_counts[p]]) % 101;
      end
    end

    count = result;
  end

endmodule