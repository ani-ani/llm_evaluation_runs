module loop_validator (
  input  wire          clk,        // clock
  input  wire          rst_n,      // active-low reset
  input  wire          start,      // start processing
  input  wire [2:0]    num_points, // number of points (1-8)
  input  wire [15:0]   x_in,       // x-coordinate (signed 16-bit)
  input  wire [15:0]   y_in,       // y-coordinate (signed 16-bit)
  input  wire          point_valid,// high when x_in/y_in are valid
  output reg           valid_loop, // 1=YES, 0=NO
  output reg           done        // high when result is valid
);

  // State machine states
  typedef enum logic [1:0] {
    IDLE,
    LOADING,
    PROCESSING,
    DONE
  } state_t;

  reg [1:0] state, next_state;
  reg [2:0] point_count;
  reg [4:0] cycle_counter;
  reg [15:0] x_point [0:7]; // Array to store x coordinates
  reg [15:0] y_point [0:7]; // Array to store y coordinates
  reg is_valid;

  // Target cycle count for processing
  wire [4:0] target_cycles = 5'd10 + {num_points, 1'b0};

  // State machine and control logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      point_count <= 0;
      cycle_counter <= 0;
      valid_loop <= 0;
      done <= 0;
      for (int i=0; i<8; i++) begin
        x_point[i] <= 16'd0;
        y_point[i] <= 16'd0;
      end
    end else begin
      state <= next_state;
      cycle_counter <= cycle_counter + (state != IDLE);

      case (state)
        IDLE: begin
          done <= 0;
          valid_loop <= 0;
          point_count <= 0;
          cycle_counter <= 0;
          if (start) begin
            next_state <= LOADING;
          end else begin
            next_state <= IDLE;
          end
        end

        LOADING: begin
          if (point_valid && point_count < num_points) begin
            x_point[point_count] <= x_in;
            y_point[point_count] <= y_in;
            point_count <= point_count + 1;
          end
          if (point_count == num_points) begin
            next_state <= PROCESSING;
          end
        end

        PROCESSING: begin
          if (cycle_counter >= target_cycles) begin
            next_state <= DONE;
          end
        end

        DONE: begin
          valid_loop <= is_valid;
          done <= 1;
          next_state <= IDLE;
        end

        default: next_state <= IDLE;
      endcase
    end
  end

  // Combinational logic for loop validation
  always_comb begin
    is_valid = 1'b1;

    if (state == DONE) begin
      // Check all points are distinct
      for (int i=0; i<num_points; i++) begin
        for (int j=i+1; j<num_points; j++) begin
          if (x_point[i] == x_point[j] && y_point[i] == y_point[j]) begin
            is_valid = 1'b0;
          end
        end
      end

      // Check segment validity and alternation
      for (int i=0; i<num_points; i++) begin
        int next_idx = (i == num_points-1) ? 0 : i+1;
        int prev_idx = (i == 0) ? num_points-1 : i-1;

        // Check current segment type (horizontal or vertical)
        logic curr_vert, curr_horz;
        curr_vert = (x_point[i] == x_point[next_idx]) && (y_point[i] != y_point[next_idx]);
        curr_horz = (y_point[i] == y_point[next_idx]) && (x_point[i] != x_point[next_idx]);

        // Check neighbor connections
        logic has_vert_neighbor, has_horz_neighbor;
        has_vert_neighbor = (x_point[i] == x_point[prev_idx]) || (x_point[i] == x_point[next_idx]);
        has_horz_neighbor = (y_point[i] == y_point[prev_idx]) || (y_point[i] == y_point[next_idx]);

        // Require exactly one vertical and one horizontal neighbor
        if (!(curr_vert || curr_horz) || $countones({has_vert_neighbor, has_horz_neighbor}) != 2) begin
          is_valid = 1'b0;
        end

        // Check segment alternation
        if (i < num_points-1) begin
          logic next_vert, next_horz;
          next_vert = (x_point[next_idx] == x_point[(next_idx == num_points-1) ? 0 : next_idx+1]) && 
                      (y_point[next_idx] != y_point[(next_idx == num_points-1) ? 0 : next_idx+1]);
          next_horz = (y_point[next_idx] == y_point[(next_idx == num_points-1) ? 0 : next_idx+1]) && 
                      (x_point[next_idx] != x_point[(next_idx == num_points-1) ? 0 : next_idx+1]);
          
          if (curr_vert == next_vert || curr_horz == next_horz) begin
            is_valid = 1'b0;
          end
        end
      end

      // Check loop closure
      if (x_point[0] != x_point[num_points-1] && y_point[0] != y_point[num_points-1]) begin
        is_valid = 1'b0;
      end

      // Simple self-intersection check (covers basic axis-aligned cases)
      for (int i=0; i<num_points; i++) begin
        for (int j=i+1; j<num_points; j++) begin
          int i_next = (i == num_points-1) ? 0 : i+1;
          int j_next = (j == num_points-1) ? 0 : j+1;

          if ((i != j) && (i != j_next) && (j != i_next)) begin
            // Check for cross intersections
            if (x_point[i] == x_point[j] && y_point[i_next] == y_point[j_next] &&
                ((y_point[i] < y_point[j_next] && y_point[i_next] > y_point[j_next]) ||
                 (y_point[i] > y_point[j_next] && y_point[i_next] < y_point[j_next])) &&
                ((x_point[j] < x_point[i] && x_point[j_next] > x_point[i]) ||
                 (x_point[j] > x_point[i] && x_point[j_next] < x_point[i]))) begin
              is_valid = 1'b0;
            end
          end
        end
      end
    end else begin
      is_valid = 1'b0;
    end
  end
endmodule