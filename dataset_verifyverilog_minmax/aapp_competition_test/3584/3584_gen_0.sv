module onion_protect(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // pulse high to start computation
  input [3:0] num_onions, // N (1-8)
  input [3:0] num_posts, // M (3-8)
  input [3:0] select_count, // K (3-4)
  input [15:0] onion_x[0:7], // X coordinates of onions (8 onions max)
  input [15:0] onion_y[0:7], // Y coordinates of onions
  input [15:0] post_x[0:7], // X coordinates of fence posts (8 posts max)
  input [15:0] post_y[0:7], // Y coordinates of fence posts
  output reg [3:0] max_protected, // maximum protected onions count
  output reg done // high when computation complete
);

  // State definitions
  localparam IDLE = 2'b00;
  localparam COMB_GEN = 2'b01;
  localparam HULL_CHECK = 2'b10;
  localparam COUNT = 2'b11;
  localparam DONE = 2'b10; // Note: HULL_CHECK and DONE use same state? We'll use DONE as separate.
  
  // We'll redefine states to avoid conflict
  localparam STATE_IDLE = 3'b000;
  localparam STATE_COMB_GEN = 3'b001;
  localparam STATE_HULL_CHECK = 3'b010;
  localparam STATE_COUNT = 3'b011;
  localparam STATE_DONE = 3'b100;

  // Registers
  reg [2:0] state, next_state;
  reg [1:0] gen_step; // for combination generation
  reg [3:0] i_reg; // index for combination generation
  reg first_combo;
  reg [3:0] comb[3:0]; // current combination
  
  // For hull check
  reg [1:0] hull_step; // 0: load and sort, 1: compute hull
  reg [15:0] points_x[3:0], points_y[3:0];
  reg [15:0] hull_x[3:0], hull_y[3:0];
  reg [3:0] hull_size;
  
  // For counting
  reg [3:0] count_i, count_j;
  reg [3:0] current_count, onion_count;
  
  // Temporary variables
  integer j, k;
  integer d1, d2, d3, num, den, temp;
  reg [3:0] temp_x, temp_y;

  // State machine
  always @(posedge clk) begin
    if (!rst_n) begin
      state <= STATE_IDLE;
      done <= 0;
      max_protected <= 0;
    end else begin
      state <= next_state;
      
      case (state)
        STATE_IDLE: begin
          if (start) begin
            max_protected <= 0;
            first_combo <= 1;
            next_state <= STATE_COMB_GEN;
          end
        end
        
        STATE_COMB_GEN: begin
          if (gen_step == 0) begin
            if (first_combo) begin
              // Initialize first combination
              for (j = 0; j < select_count; j++) begin
                comb[j] = j;
              end
              first_combo <= 0;
              next_state <= STATE_HULL_CHECK;
            end else begin
              i_reg = select_count - 1;
              gen_step <= 1;
            end
          end else if (gen_step == 1) begin
            if (comb[i_reg] < num_posts - select_count + i_reg) begin
              comb[i_reg] <= comb[i_reg] + 1;
              for (j = i_reg + 1; j < select_count; j++) begin
                comb[j] <= comb[j-1] + 1;
              end
              next_state <= STATE_HULL_CHECK;
            end else if (i_reg > 0) begin
              i_reg = i_reg - 1;
            end else begin
              next_state <= STATE_DONE;
            end
          end
        end
        
        STATE_HULL_CHECK: begin
          if (hull_step == 0) begin
            // Load points and sort (bubble sort one pass)
            for (j = 0; j < select_count; j++) begin
              points_x[j] <= post_x[comb[j]];
              points_y[j] <= post_y[comb[j]];
            end
            
            for (j = 0; j < select_count - 1; j++) begin
              if (points_x[j] > points_x[j+1] || 
                  (points_x[j] == points_x[j+1] && points_y[j] > points_y[j+1])) begin
                temp_x = points_x[j];
                points_x[j] <= points_x[j+1];
                points_x[j+1] <= temp_x;
                temp_y = points_y[j];
                points_y[j] <= points_y[j+1];
                points_y[j+1] <= temp_y;
              end
            end
            hull_step <= 1;
          end else if (hull_step == 1) begin
            if (select_count == 3) begin
              hull_x[0] <= points_x[0]; hull_y[0] <= points_y[0];
              hull_x[1] <= points_x[1]; hull_y[1] <= points_y[1];
              hull_x[2] <= points_x[2]; hull_y[2] <= points_y[2];
              hull_size <= 3;
            end else if (select_count == 4) begin
              // Point-in-triangle test for fourth point
              d1 = (points_x[1]-points_x[0]) * (points_y[3]-points_y[0]) - 
                   (points_y[1]-points_y[0]) * (points_x[3]-points_x[0]);
              d2 = (points_x[2]-points_x[1]) * (points_y[3]-points_y[1]) - 
                   (points_y[2]-points_y[1]) * (points_x[3]-points_x[1]);
              d3 = (points_x[0]-points_x[2]) * (points_y[3]-points_y[2]) - 
                   (points_y[0]-points_y[2]) * (points_x[3]-points_x[2]);
              
              if ((d1 >= 0 && d2 >= 0 && d3 >= 0) || 
                  (d1 <= 0 && d2 <= 0 && d3 <= 0)) begin
                hull_x[0] <= points_x[0]; hull_y[0] <= points_y[0];
                hull_x[1] <= points_x[1]; hull_y[1] <= points_y[1];
                hull_x[2] <= points_x[2]; hull_y[2] <= points_y[2];
                hull_size <= 3;
              end else begin
                hull_x[0] <= points_x[0]; hull_y[0] <= points_y[0];
                hull_x[1] <= points_x[1]; hull_y[1] <= points_y[1];
                hull_x[2] <= points_x[2]; hull_y[2] <= points_y[2];
                hull_x[3] <= points_x[3]; hull_y[3] <= points_y[3];
                hull_size <= 4;
              end
            end
            
            // Initialize counting variables
            count_i <= 0;
            count_j <= 0;
            current_count <= 0;
            onion_count <= 0;
            next_state <= STATE_COUNT;
          end
        end
        
        STATE_COUNT: begin
          if (count_i < num_onions) begin
            if (count_j < hull_size) begin
              j = (count_j + 1) % hull_size;
              
              num = (hull_x[j] - hull_x[count_j]) * (onion_y[count_i] - hull_y[count_j]);
              den = (hull_y[j] - hull_y[count_j]);
              
              if (den > 0) begin
                if (num > (onion_x[count_i] - hull_x[count_j]) * den) begin
                  current_count <= current_count + 1;
                end
              end else begin
                if (num < (onion_x[count_i] - hull_x[count_j]) * den) begin
                  current_count <= current_count + 1;
                end
              end
              count_j <= count_j + 1;
            end else begin
              if (current_count[0] == 1) begin // odd count
                onion_count <= onion_count + 1;
              end
              count_i <= count_i + 1;
              count_j <= 0;
              current_count <= 0;
            end
          end else begin
            if (onion_count > max_protected) begin
              max_protected <= onion_count;
            end
            next_state <= STATE_COMB_GEN;
          end
        end
        
        STATE_DONE: begin
          done <= 1;
        end
      endcase
    end
  end
endmodule