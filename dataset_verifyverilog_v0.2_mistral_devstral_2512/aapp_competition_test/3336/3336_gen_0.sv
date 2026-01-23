module max_eligible_pupils (
  input clk,
  input rst_n,
  input start,
  input [4:0] num_pupils,
  input [7:0] heights [0:15],
  input [0:15] sexes,
  input [2:0] music [0:15],
  input [2:0] sport [0:15],
  output reg [4:0] max_persons,
  output reg done,
  output reg valid
);

  // State definitions
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] GEN_CONFLICT = 3'b001;
  localparam [2:0] INIT_SEARCH = 3'b010;
  localparam [2:0] CHECK_SUBSET = 3'b011;
  localparam [2:0] INCREMENT = 3'b100;
  localparam [2:0] DONE_STATE = 3'b101;

  reg [2:0] state;
  reg [15:0] conflict_mask [0:15];
  reg [15:0] current_subset;
  reg [4:0] best_size;
  reg [4:0] i_reg, j_reg;
  reg [4:0] check_i_reg;
  reg valid_subset;
  reg [4:0] popcount_reg;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      max_persons <= 0;
      done <= 0;
      valid <= 0;
      i_reg <= 0;
      j_reg <= 0;
      check_i_reg <= 0;
      current_subset <= 0;
      best_size <= 0;
      valid_subset <= 0;
      popcount_reg <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= GEN_CONFLICT;
            i_reg <= 0;
            j_reg <= 0;
          end
        end
        GEN_CONFLICT: begin
          if (i_reg == num_pupils - 1 && j_reg == num_pupils) begin
            state <= INIT_SEARCH;
          end else if (j_reg == num_pupils) begin
            i_reg <= i_reg + 1;
            j_reg <= i_reg + 1;
          end else begin
            // Compute conflict condition
            reg [7:0] diff;
            reg sex_eq, music_eq, sport_neq;
            diff = (heights[i_reg] > heights[j_reg]) ? (heights[i_reg] - heights[j_reg]) : (heights[j_reg] - heights[i_reg]);
            sex_eq = (sexes[i_reg] == sexes[j_reg]);
            music_eq = (music[i_reg] == music[j_reg]);
            sport_neq = (sport[i_reg] != sport[j_reg]);
            if (diff <= 40 && sex_eq && music_eq && sport_neq) begin
              conflict_mask[i_reg][j_reg] <= 1;
              conflict_mask[j_reg][i_reg] <= 1;
            end else begin
              conflict_mask[i_reg][j_reg] <= 0;
              conflict_mask[j_reg][i_reg] <= 0;
            end
            j_reg <= j_reg + 1;
          end
        end
        INIT_SEARCH: begin
          current_subset <= 1;
          best_size <= 0;
          state <= CHECK_SUBSET;
          check_i_reg <= 0;
          valid_subset <= 1;
          popcount_reg <= 0;
        end
        CHECK_SUBSET: begin
          if (check_i_reg == num_pupils) begin
            if (valid_subset && popcount_reg > best_size) begin
              best_size <= popcount_reg;
            end
            state <= INCREMENT;
          end else begin
            if (current_subset[check_i_reg]) begin
              popcount_reg <= popcount_reg + 1;
              // Check conflict with neighbors
              if (current_subset & conflict_mask[check_i_reg]) begin
                valid_subset <= 0;
              end
            end
            check_i_reg <= check_i_reg + 1;
          end
        end
        INCREMENT: begin
          if (current_subset == (1 << num_pupils) - 1) begin
            state <= DONE_STATE;
          end else begin
            current_subset <= current_subset + 1;
            state <= CHECK_SUBSET;
            check_i_reg <= 0;
            valid_subset <= 1;
            popcount_reg <= 0;
          end
        end
        DONE_STATE: begin
          done <= 1;
          valid <= 1;
          max_persons <= best_size;
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule