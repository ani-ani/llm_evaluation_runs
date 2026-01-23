module max_eligible_pupils (
    input clk,
    input rst_n, // active low
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

// Register declarations
reg [2:0] state;
reg [4:0] n;
reg [15:0] conflict_matrix [15:0];
reg [15:0] current_subset, max_subset;
reg [3:0] i, j;
reg [4:0] best_size;

// Combinatorial signals for conflict
wire [7:0] h_i, h_j;
wire [7:0] diff;
wire sex_eq;
wire [2:0] music_i, music_j, sport_i, sport_j;
wire music_eq, sport_neq;
wire conflict;

// Compute 2^n
localparam MAX_N =16;
reg [15:0] pow2_n;
always_comb begin
   case (n)
      1: pow2_n = 2;
      2: pow2_n =4;
      3: pow2_n =8;
      4: pow2_n =16;
      5: pow2_n =32;
      6: pow2_n =64;
      7: pow2_n =128;
      8: pow2_n =256;
      9: pow2_n =512;
      10: pow2_n =1024;
      11: pow2_n =2048;
      12: pow2_n =4096;
      13: pow2_n =8192;
      14: pow2_n =16384;
      15: pow2_n =32768;
      16: pow2_n =65536;
      default: pow2_n =1;
   endcase
end

// Unrolled popcount
reg [3:0] subset_size;
always_comb begin
   subset_size =0;
   if (current_subset & 1) subset_size++;
   if (current_subset & 2) subset_size++;
   if (current_subset & 4) subset_size++;
   if (current_subset & 8) subset_size++;
   if (current_subset & 16) subset_size++;
   if (current_subset & 32) subset_size++;
   if (current_subset & 64) subset_size++;
   if (current_subset & 128) subset_size++;
   if (current_subset & 256) subset_size++;
   if (current_subset & 512) subset_size++;
   if (current_subset & 1024) subset_size++;
   if (current_subset & 2048) subset_size++;
   if (current_subset & 4096) subset_size++;
   if (current_subset & 8192) subset_size++;
   if (current_subset & 16384) subset_size++;
   if (current_subset & 32768) subset_size++;
end

// Combinatorial conflict computation
always_comb begin
   h_i = heights[i];
   h_j = heights[j];
   diff = (h_i > h_j) ? h_i - h_j : h_j - h_i;
   sex_eq = (sexes[i] == sexes[j]);
   music_i = music[i];
   music_j = music[j];
   music_eq = (music_i == music_j);
   sport_i = sport[i];
   sport_j = sport[j];
   sport_neq = (sport_i != sport_j);
   conflict = (diff <=40) && sex_eq && music_eq && sport_neq;
end

// Combinatorial valid_subset computation
wire valid_subset;
always_comb begin
   valid_subset =1'b1;
   genvar ii, jj;
   generate
      for (ii=0; ii<16; ii++) begin
         if (current_subset & (1<<ii)) begin
            for (jj=ii+1; jj<16; jj++) begin
               if (current_subset & (1<<jj)) begin
                  if (conflict_matrix[ii][jj]) begin
                     valid_subset =1'b0;
                  end
               end
            end
         end
      end
   endgenerate
end

// State machine
always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      state <= 0;
      n <=0;
      best_size <=0;
      conflict_matrix <=0;
      current_subset <=0;
      max_subset <=0;
      i <=0;
      j <=0;
      done <=0;
      valid <=0;
      max_persons <=0;
   end else begin
      case (state)
         0: begin // IDLE
            if (start) begin
               n <= num_pupils;
               state <= 1;
            end
         end
         1: begin // CALC_EDGES
            if (i < n) begin
               if (j < n) begin
                  if (conflict) begin
                     conflict_matrix[i][j] <=1;
                     conflict_matrix[j][i] <=1;
                  end
               end
               if (j < n-1) begin
                  j <= j +1;
               end else begin
                  j <=0;
                  if (i < n-1) begin
                     i <= i +1;
                  end else begin
                     state <= 2; // INIT
                  end
               end
            end
         end
         2: begin // INIT
            best_size <=0;
            current_subset <=1;
            max_subset <= pow2_n -1;
            state <=3; // SEARCH
         end
         3: begin // SEARCH
            if (valid_subset) begin
               if (subset_size > best_size) begin
                  best_size <= subset_size;
               end
            end
            if (current_subset < max_subset) begin
               current_subset <= current_subset +1;
            end else begin
               state <=4; // DONE
               done <=1;
               valid <=1;
               max_persons <= best_size;
            end
         end
         4: begin // DONE
            done <=1;
            valid <=1;
            max_persons <= best_size;
         end
      endcase
   end
end

// State definitions
localparam IDLE =0, CALC_EDGES=1, INIT=2, SEARCH=3, DONE=4;
initial begin
   state <= IDLE;
end

endmodule