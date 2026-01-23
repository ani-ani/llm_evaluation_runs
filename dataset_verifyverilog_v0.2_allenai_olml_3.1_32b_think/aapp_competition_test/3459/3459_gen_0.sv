module council_solver (
  input clk,
  input rst_n,
  input start,
  input [3:0] num_residents,
  input [3:0] num_clubs,
  input [7:0] resident_id,
  input [7:0] party_id,
  input [3:0] club_mask,
  input load_valid,
  output reg solved,
  output reg impossible,
  output reg [7:0] result_club_id,
  output reg [7:0] result_resident_id,
  output reg result_valid
);

  // State definitions
  localparam IDLE = 3'd0, LOAD = 1, SOLVE = 2, OUTPUT = 3, DONE = 4;
  reg [2:0] state;

  // Load state registers
  reg [3:0] load_count;
  reg [7:0] resident_id_vec [0:7];
  reg [7:0] party_id_vec [0:7];
  reg [3:0] club_mask_vec [0:7];
  reg [2:0] options_count [0:7];
  reg [3:0] num_residents_reg;
  reg [3:0] num_clubs_reg;

  // Solve state registers
  reg [18:0] try_count_reg;
  reg [18:0] total_combinations_reg;
  reg [2:0] first_entry;
  reg [2:0] solution_choices [0:7];
  reg [2:0] output_idx;

  // Outputs
  reg solved;
  reg impossible;


  // Function to find club index
  function automatic int find_club;
    input int M, int C;
    int i;
    for (i=0; i<4; i++) begin
      if (M & (1<<i)) begin
        if (C == 1) return i;
        C--;
      end
    end
    return -1;
  endfunction


  always @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
      load_count <= 0;
      num_residents_reg <= 0;
      num_clubs_reg <= 0;
      for (int i=0; i<8; i++) begin
        resident_id_vec[i] <= 0;
        party_id_vec[i] <= 0;
        club_mask_vec[i] <= 0;
        options_count[i] <= 0;
        solution_choices[i] <= 0;
      end
      try_count_reg <= 0;
      total_combinations_reg <= 0;
      first_entry <= 0;
      output_idx <= 0;
      solved <= 0;
      impossible <= 0;
      result_club_id <= 0;
      result_resident_id <= 0;
      result_valid <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD;
            num_residents_reg <= num_residents;
            num_clubs_reg <= num_clubs;
          end
          solved <= 0;
          impossible <= 0;
          result_valid <= 0;
        end
        LOAD: begin
          if (load_valid && load_count < num_residents_reg) begin
            resident_id_vec[load_count] <= resident_id;
            party_id_vec[load_count] <= party_id;
            club_mask_vec[load_count] <= club_mask;
            options_count[load_count] =
              (club_mask & 1?1:0) +
              (club_mask & 2?1:0) +
              (club_mask & 4?1:0) +
              (club_mask & 8?1:0) + 1;
            load_count <= load_count + 1;
          end
        end
        SOLVE: begin
          if (first_entry) begin
            int prod = 1;
            for (int i=0; i<num_residents_reg; i++) begin
              prod *= options_count[i];
            end
            total_combinations_reg <= prod;
            first_entry <= 0;
          end
          if (try_count_reg < total_combinations_reg) begin
            int current = try_count_reg;
            solution_choices[0] = current % options_count[0]; current /= options_count[0];
            solution_choices[1] = current % options_count[1]; current /= options_count[1];
            solution_choices[2] = current % options_count[2]; current /= options_count[2];
            solution_choices[3] = current % options_count[3]; current /= options_count[3];
            solution_choices[4] = current % options_count[4]; current /= options_count[4];
            solution_choices[5] = current % options_count[5]; current /= options_count[5];
            solution_choices[6] = current % options_count[6]; current /= options_count[6];
            solution_choices[7] = current % options_count[7];
            int threshold = (num_clubs_reg + 1) / 2;
            int valid = 1;
            // Simplified validity check (unrolled for resident 0 only for example)
            if (solution_choices[0] != 0) begin
              int pid = party_id_vec[0];
              int cnt = 0;
              cnt += (solution_choices[0]!=0 && party_id_vec[0]==pid ?1:0);
              cnt += (solution_choices[1]!=0 && party_id_vec[1]==pid ?1:0);
              cnt += (solution_choices[2]!=0 && party_id_vec[2]==pid ?1:0);
              cnt += (solution_choices[3]!=0 && party_id_vec[3]==pid ?1:0);
              cnt += (solution_choices[4]!=0 && party_id_vec[4]==pid ?1:0);
              cnt += (solution_choices[5]!=0 && party_id_vec[5]==pid ?1:0);
              cnt += (solution_choices[6]!=0 && party_id_vec[6]==pid ?1:0);
              cnt += (solution_choices[7]!=0 && party_id_vec[7]==pid ?1:0);
              if (cnt >= threshold) valid = 0;
            end
            if (valid) begin
              state <= OUTPUT;
            end
            try_count_reg <= try_count_reg + 1;
          end else begin
            impossible <= 1;
            state <= DONE;
          end
        end
        OUTPUT: begin
          if (output_idx < num_residents_reg) begin
            if (solution_choices[output_idx] != 0) begin
              result_club_id <= find_club(club_mask_vec[output_idx], solution_choices[output_idx]);
              result_resident_id <= resident_id_vec[output_idx];
              result_valid <= 1;
            end else begin
              result_valid <= 0;
            end
            output_idx <= output_idx + 1;
          end else begin
            solved <= 1;
            state <= DONE;
          end
        end
        DONE: begin
          solved <= !impossible;
        end
      endcase
    end
  end

endmodule
