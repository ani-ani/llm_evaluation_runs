module card_game (
  input clk,
  input rst_n,
  input start,
  input [7:0] n, m,
  input [15:0] jiro_strength [0:99],
  input [99:0] jiro_type,  // 0 for DEF, 1 for ATK
  input [15:0] ciel_strength [0:99],
  output reg [15:0] result,
  output reg done
);

// State definitions
localparam [3:0] IDLE = 4'd0;
localparam [3:0] READ_N_M = 4'd1;
localparam [3:0] READ_JIRO = 4'd2;
localparam [3:0] READ_CIEL = 4'd3;
localparam [3:0] SEPARATE = 4'd4;
localparam [3:0] SORT_DEF = 4'd5;
localparam [3:0] SORT_ATK = 4'd6;
localparam [3:0] SORT_CIEL = 4'd7;
localparam [3:0] COMPUTE_TOTAL_CIEL = 4'd8;
localparam [3:0] POSS1_DEF = 4'd9;
localparam [3:0] POSS1_ATK = 4'd10;
localparam [3:0] POSS2 = 4'd11;
localparam [3:0] COMPUTE_RESULT = 4'd12;
localparam [3:0] DONE = 4'd13;

reg [3:0] state;
reg [7:0] i, j, k;
reg [15:0] def_list [0:99];
reg [15:0] atk_list [0:99];
reg [15:0] ciel_sorted [0:99];
reg [99:0] used;
reg [15:0] total_ciel;
reg [15:0] sum_def_used;
reg [15:0] damage1, damage2;
reg [7:0] num_def, num_atk;
reg [15:0] temp;
reg found;

// For Possibility 2
reg [15:0] sum_c, sum_a;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 1'b0;
    result <= 16'd0;
    i <= 8'd0;
    j <= 8'd0;
    k <= 8'd0;
    num_def <= 8'd0;
    num_atk <= 8'd0;
    total_ciel <= 16'd0;
    sum_def_used <= 16'd0;
    damage1 <= 16'd0;
    damage2 <= 16'd0;
    sum_c <= 16'd0;
    sum_a <= 16'd0;
    used <= 100'd0;
  end else begin
    case (state)
      IDLE: begin
        if (start) begin
          state <= READ_N_M;
          i <= 8'd0;
          j <= 8'd0;
          k <= 8'd0;
          num_def <= 8'd0;
          num_atk <= 8'd0;
          total_ciel <= 16'd0;
          sum_def_used <= 16'd0;
          damage1 <= 16'd0;
          damage2 <= 16'd0;
          sum_c <= 16'd0;
          sum_a <= 16'd0;
          used <= 100'd0;
          done <= 1'b0;
        end
      end

      READ_N_M: begin
        // n and m are already provided, move to reading Jiro cards
        state <= READ_JIRO;
      end

      READ_JIRO: begin
        // Store Jiro cards into def_list and atk_list based on type
        if (i < n) begin
          if (jiro_type[i] == 1'b0) begin
            def_list[num_def] <= jiro_strength[i];
            num_def <= num_def + 8'd1;
          end else begin
            atk_list[num_atk] <= jiro_strength[i];
            num_atk <= num_atk + 8'd1;
          end
          i <= i + 8'd1;
        end else begin
          i <= 8'd0;
          state <= READ_CIEL;
        end
      end

      READ_CIEL: begin
        // Store Ciel cards into ciel_sorted
        if (i < m) begin
          ciel_sorted[i] <= ciel_strength[i];
          i <= i + 8'd1;
        end else begin
          i <= 8'd0;
          state <= SEPARATE;
        end
      end

      SEPARATE: begin
        // Separate completed, move to sorting
        state <= SORT_DEF;
        i <= 8'd0;
        j <= 8'd0;
      end

      SORT_DEF: begin
        // Bubble sort def_list
        if (i < num_def) begin
          if (j < num_def - 8'd1) begin
            if (def_list[j] > def_list[j+8'd1]) begin
              temp <= def_list[j];
              def_list[j] <= def_list[j+8'd1];
              def_list[j+8'd1] <= temp;
            end
            j <= j + 8'd1;
          end else begin
            j <= 8'd0;
            i <= i + 8'd1;
          end
        end else begin
          i <= 8'd0;
          j <= 8'd0;
          state <= SORT_ATK;
        end
      end

      SORT_ATK: begin
        // Bubble sort atk_list
        if (i < num_atk) begin
          if (j < num_atk - 8'd1) begin
            if (atk_list[j] > atk_list[j+8'd1]) begin
              temp <= atk_list[j];
              atk_list[j] <= atk_list[j+8'd1];
              atk_list[j+8'd1] <= temp;
            end
            j <= j + 8'd1;
          end else begin
            j <= 8'd0;
            i <= i + 8'd1;
          end
        end else begin
          i <= 8'd0;
          j <= 8'd0;
          state <= SORT_CIEL;
        end
      end

      SORT_CIEL: begin
        // Bubble sort ciel_sorted
        if (i < m) begin
          if (j < m - 8'd1) begin
            if (ciel_sorted[j] > ciel_sorted[j+8'd1]) begin
              temp <= ciel_sorted[j];
              ciel_sorted[j] <= ciel_sorted[j+8'd1];
              ciel_sorted[j+8'd1] <= temp;
            end
            j <= j + 8'd1;
          end else begin
            j <= 8'd0;
            i <= i + 8'd1;
          end
        end else begin
          i <= 8'd0;
          j <= 8'd0;
          state <= COMPUTE_TOTAL_CIEL;
        end
      end

      COMPUTE_TOTAL_CIEL: begin
        if (i < m) begin
          total_ciel <= total_ciel + ciel_sorted[i];
          i <= i + 8'd1;
        end else begin
          i <= 8'd0;
          j <= 8'd0;
          used <= 100'd0;
          sum_def_used <= 16'd0;
          state <= POSS1_DEF;
        end
      end

      POSS1_DEF: begin
        if (i < num_def) begin
          found <= 1'b0;
          if (j < m) begin
            if (!used[j] && ciel_sorted[j] > def_list[i]) begin
              used[j] <= 1'b1;
              sum_def_used <= sum_def_used + ciel_sorted[j];
              found <= 1'b1;
            end
            j <= j + 8'd1;
          end else begin
            if (!found) begin
              // Cannot destroy this DEF card
              damage1 <= 16'd0;
              state <= POSS2;
              i <= 8'd0;
              j <= 8'd0;
            end else begin
              i <= i + 8'd1;
              j <= 8'd0;
            end
          end
        end else begin
          // All DEF destroyed, move to ATK destruction
          i <= 8'd0;
          j <= 8'd0;
          state <= POSS1_ATK;
        end
      end

      POSS1_ATK: begin
        if (i < num_atk) begin
          found <= 1'b0;
          if (j < m) begin
            if (!used[j] && ciel_sorted[j] >= atk_list[i]) begin
              used[j] <= 1'b1;
              found <= 1'b1;
            end
            j <= j + 8'd1;
          end else begin
            if (!found) begin
              damage1 <= 16'd0;
              state <= POSS2;
              i <= 8'd0;
              j <= 8'd0;
            end else begin
              i <= i + 8'd1;
              j <= 8'd0;
            end
          end
        end else begin
          // All ATK destroyed, compute damage1
          // damage1 = total_ciel - sum_def_used - sum(atk_list)
          temp <= 16'd0;
          i <= 8'd0;
          state <= COMPUTE_RESULT;
        end
      end

      POSS2: begin
        // Possibility 2: destroy only some ATK cards
        // We use the largest k Ciel cards and smallest k ATK cards
        // Sort ATK already in ascending order, ciel_sorted in ascending order
        // So largest k Ciel cards are ciel_sorted[m-1], ciel_sorted[m-2], ... 
        // Smallest k ATK cards are atk_list[0], atk_list[1], ...
        if (i < num_atk && i < m) begin
          // Check if the i-th largest Ciel card (ciel_sorted[m-1-i]) >= i-th smallest ATK card (atk_list[i])
          if (ciel_sorted[m-8'd1-i] >= atk_list[i]) begin
            sum_c <= sum_c + ciel_sorted[m-8'd1-i];
            sum_a <= sum_a + atk_list[i];
            // Compute damage for this k = i+1
            damage2 <= (sum_c + ciel_sorted[m-8'd1-i]) - (sum_a + atk_list[i]);
            i <= i + 8'd1;
          end else begin
            // Stop when condition fails
            state <= COMPUTE_RESULT;
            i <= 8'd0;
          end
        end else begin
          state <= COMPUTE_RESULT;
          i <= 8'd0;
        end
      end

      COMPUTE_RESULT: begin
        if (i == 8'd0) begin
          // Compute damage1 if not done
          if (damage1 == 16'd0 && state == POSS1_ATK && i >= num_atk) begin
            // Actually, we need to compute damage1 here
            // damage1 = total_ciel - sum_def_used - sum(atk_list)
            temp <= 16'd0;
            i <= 8'd1; // Mark that we are computing damage1
          end else begin
            i <= 8'd2; // Mark that we are comparing
          end
        end else if (i == 8'd1) begin
          // Compute sum of atk_list
          if (j < num_atk) begin
            temp <= temp + atk_list[j];
            j <= j + 8'd1;
          end else begin
            damage1 <= total_ciel - sum_def_used - temp;
            i <= 8'd2;
            j <= 8'd0;
          end
        end else if (i == 8'd2) begin
          // Compare damage1 and damage2
          if (damage1 > damage2) begin
            result <= damage1;
          end else begin
            result <= damage2;
          end
          state <= DONE;
        end
      end

      DONE: begin
        done <= 1'b1;
        state <= IDLE;
      end

      default: state <= IDLE;
    endcase
  end
end

endmodule