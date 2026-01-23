module el_garizm_coexistence (
  input clk,
  input rst_n,
  input start,
  input [2:0] island_idx,
  input [2:0] resource_idx,
  input resource_valid,
  input input_done,
  output reg result,
  output reg done
);

  // State machine states
  typedef enum logic [1:0] {
    IDLE,
    INPUT,
    VERIFY,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Adjacency matrix: 8 islands x 8 resources
  reg [7:0] adj_matrix [7:0];

  // Resource-to-island pairs (each resource has exactly 2 islands)
  reg [2:0] resource_islands [7:0];
  reg [7:0] resource_count;

  // Verification counter (0 to 255 for all possible assignments)
  reg [7:0] verify_counter;

  // Temporary variables for verification
  reg [7:0] current_assignment;
  reg [7:0] valid_assignment;

  // State machine register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // State machine next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = INPUT;
      end
      INPUT: begin
        if (input_done) next_state = VERIFY;
      end
      VERIFY: begin
        if (verify_counter == 255) next_state = DONE;
      end
      DONE: next_state = IDLE;
    endcase
  end

  // Input phase: collect resource-to-island mappings
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 8; i++) begin
        adj_matrix[i] <= 0;
        resource_islands[i] <= 0;
      end
      resource_count <= 0;
    end else if (current_state == INPUT && resource_valid) begin
      adj_matrix[island_idx][resource_idx] <= 1;
      if (resource_count[resource_idx] == 0) begin
        resource_islands[resource_idx] <= island_idx;
        resource_count[resource_idx] <= resource_count[resource_idx] + 1;
      end else if (resource_count[resource_idx] == 1) begin
        resource_islands[resource_idx] <= {resource_islands[resource_idx], island_idx};
        resource_count[resource_idx] <= resource_count[resource_idx] + 1;
      end
    end
  end

  // Verification phase: check all 256 assignments
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      verify_counter <= 0;
      current_assignment <= 0;
      valid_assignment <= 0;
    end else if (current_state == VERIFY) begin
      if (verify_counter == 0) begin
        current_assignment <= 0;
        valid_assignment <= 0;
      end

      // Check current assignment
      reg [7:0] temp_valid = 1;
      for (int r = 0; r < 8; r++) begin
        if (resource_count[r] == 2) begin
          reg [2:0] island1 = resource_islands[r][5:3];
          reg [2:0] island2 = resource_islands[r][2:0];
          if (current_assignment[island1] == current_assignment[island2]) begin
            temp_valid = 0;
          end
        end
      end

      if (temp_valid) begin
        valid_assignment <= 1;
      end

      // Increment counter
      if (verify_counter < 255) begin
        verify_counter <= verify_counter + 1;
        current_assignment <= current_assignment + 1;
      end
    end
  end

  // Output phase: set result and done
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
    end else if (current_state == DONE) begin
      result <= valid_assignment;
      done <= 1;
    end else begin
      done <= 0;
    end
  end

endmodule