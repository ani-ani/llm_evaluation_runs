module name_ordering_counter(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start computation
  input [3:0][31:0] names, // 4 names (32b each: 4 ASCII chars)
  output reg [15:0] count, // Result
  output reg done // High when result valid
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE   = 3'd0,
    GROUP1 = 3'd1,
    GROUP2 = 3'd2,
    CALC   = 3'd3,
    DONE   = 3'd4
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [15:0] g1_factorial;
  reg [15:0] g2_factorial;
  reg [15:0] g3_factorial;
  reg [15:0] g4_factorial;
  reg [15:0] product_reg;

  // Grouping data
  reg [7:0] c1 [3:0]; // first char
  reg [7:0] c2 [3:0]; // second char

  // Level-1 groups (by first character)
  reg [1:0] g1_idx0, g1_idx1, g1_idx2, g1_idx3;
  reg [1:0] g1_size [3:0];
  reg [7:0] g1_char [3:0];
  reg [1:0] g1_count; // number of level-1 groups used (1..4)

  // Level-2 subgroup sizes per level-1 group (by second character)
  reg [1:0] sub_size [3:0][3:0];
  reg [7:0] sub_char [3:0][3:0];
  reg [1:0] sub_count [3:0]; // number of subgroups in each level-1 group

  // Factorial ROM function (1..4)
  function automatic [15:0] fact4(input [2:0] n);
    case (n)
      3'd0: fact4 = 16'd1; // treat 0! as 1 for safety
      3'd1: fact4 = 16'd1;
      3'd2: fact4 = 16'd2;
      3'd3: fact4 = 16'd6;
      3'd4: fact4 = 16'd24;
      default: fact4 = 16'd1;
    endcase
  endfunction

  // Sequential state register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Main sequential logic
  integer i, j, k;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count        <= 16'd0;
      done         <= 1'b0;
      g1_factorial <= 16'd1;
      g2_factorial <= 16'd1;
      g3_factorial <= 16'd1;
      g4_factorial <= 16'd1;
      product_reg  <= 16'd1;
      g1_count     <= 2'd0;
      for (i = 0; i < 4; i = i + 1) begin
        g1_size[i]   <= 2'd0;
        g1_char[i]   <= 8'd0;
        sub_count[i] <= 2'd0;
        for (j = 0; j < 4; j = j + 1) begin
          sub_size[i][j] <= 2'd0;
          sub_char[i][j] <= 8'd0;
        end
      end
    end else begin
      done <= 1'b0;

      case (state)
        IDLE: begin
          count        <= 16'd0;
          product_reg  <= 16'd1;
          g1_factorial <= 16'd1;
          g2_factorial <= 16'd1;
          g3_factorial <= 16'd1;
          g4_factorial <= 16'd1;
          if (start) begin
            // Capture first two chars for all names
            for (i = 0; i < 4; i = i + 1) begin
              c1[i] <= names[i][31:24];
              c2[i] <= names[i][23:16];
            end
            // Initialize grouping structures
            g1_count <= 2'd0;
            for (i = 0; i < 4; i = i + 1) begin
              g1_size[i]   <= 2'd0;
              g1_char[i]   <= 8'd0;
              sub_count[i] <= 2'd0;
              for (j = 0; j < 4; j = j + 1) begin
                sub_size[i][j] <= 2'd0;
                sub_char[i][j] <= 8'd0;
              end
            end
          end
        end

        // GROUP1: group by first character
        GROUP1: begin
          // Build level-1 groups (simple insertion into up to 4 groups)
          g1_count <= 2'd0;
          for (i = 0; i < 4; i = i + 1) begin
            // Try to find existing group
            reg found;
            found = 1'b0;
            for (j = 0; j < g1_count; j = j + 1) begin
              if (c1[i] == g1_char[j]) begin
                g1_size[j] <= g1_size[j] + 2'd1;
                found = 1'b1;
              end
            end
            if (!found) begin
              g1_char[g1_count] <= c1[i];
              g1_size[g1_count] <= 2'd1;
              g1_count          <= g1_count + 2'd1;
            end
          end
        end

        // GROUP2: for each level-1 group, group its members by second character
        GROUP2: begin
          // Reset subgroups
          for (i = 0; i < 4; i = i + 1) begin
            sub_count[i] <= 2'd0;
            for (j = 0; j < 4; j = j + 1) begin
              sub_size[i][j] <= 2'd0;
              sub_char[i][j] <= 8'd0;
            end
          end

          // For each name, find its level-1 group, then level-2 subgroup
          for (i = 0; i < 4; i = i + 1) begin
            // Find L1 group index gi
            reg [1:0] gi;
            gi = 2'd0;
            for (j = 0; j < g1_count; j = j + 1) begin
              if (c1[i] == g1_char[j]) begin
                gi = j[1:0];
              end
            end

            // Insert into subgroup within group gi based on c2
            reg found2;
            found2 = 1'b0;
            for (k = 0; k < sub_count[gi]; k = k + 1) begin
              if (c2[i] == sub_char[gi][k]) begin
                sub_size[gi][k] <= sub_size[gi][k] + 2'd1;
                found2 = 1'b1;
              end
            end
            if (!found2) begin
              sub_char[gi][sub_count[gi]] <= c2[i];
              sub_size[gi][sub_count[gi]] <= 2'd1;
              sub_count[gi]               <= sub_count[gi] + 2'd1;
            end
          end
        end

        // CALC: compute product of factorials (two levels)
        CALC: begin
          product_reg  <= 16'd1;
          g1_factorial <= 16'd1;
          g2_factorial <= 16'd1;
          g3_factorial <= 16'd1;
          g4_factorial <= 16'd1;

          // Level-1 factorials (by first char groups)
          for (i = 0; i < g1_count; i = i + 1) begin
            g1_factorial <= g1_factorial * fact4(g1_size[i]);
          end

          // Level-2 factorials (per second-char subgroup under each first-char group)
          for (i = 0; i < g1_count; i = i + 1) begin
            for (j = 0; j < sub_count[i]; j = j + 1) begin
              g2_factorial <= g2_factorial * fact4(sub_size[i][j]);
            end
          end

          // Final product
          product_reg <= g1_factorial * g2_factorial;
        end

        DONE: begin
          count <= product_reg;
          done  <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // Next state logic (5-cycle latency from start)
  // IDLE (cycle 0) -> GROUP1 (1) -> GROUP2 (2) -> CALC (3) -> DONE (4)
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = GROUP1;
      end
      GROUP1: begin
        next_state = GROUP2;
      end
      GROUP2: begin
        next_state = CALC;
      end
      CALC: begin
        next_state = DONE;
      end
      DONE: begin
        // Wait for start deassertion then new start
        if (!start)
          next_state = IDLE;
        else
          next_state = DONE;
      end
      default: next_state = IDLE;
    endcase
  end

endmodule