module fence_painter(
  input clk,
  input rst_n,
  input start,
  input [3:0] num_offers,
  input [7:0][15:0] offer_data,
  output reg [3:0] min_count,
  output reg impossible,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] { IDLE, RUN, DONE } state_t;
  state_t state;

  // Internal registers
  reg [7:0] current_mask;
  reg [3:0] best_count;
  reg best_found;
  reg [15:0] coverage_comb;
  reg [7:0] color_present_comb;

  // Combinational valid checks
  wire valid_mask = (current_mask != 0) && (current_mask < (1 << num_offers));
  wire coverage_full = (coverage_comb == 16'hFFFF);
  wire [3:0] color_count = $countones(color_present_comb);
  wire color_valid = (color_count <= 3'd3);
  wire [3:0] num_in_mask = $countones(current_mask);

  // Coverage and color present calculation
  always_comb begin
    coverage_comb = 16'h0000;
    color_present_comb = 8'h00;
    for (int i = 0; i < 8; i = i + 1) begin
      if (current_mask[i] && (i < num_offers)) begin
        // Extract offer details
        logic [2:0] col = offer_data[i][15:13];
        logic [3:0] start_section = offer_data[i][12:9];
        logic [3:0] end_section = offer_data[i][8:5];
        // Generate offer coverage
        for (int s = start_section; s <= end_section; s = s + 1) begin
          coverage_comb[s] = 1'b1;
        end
        // Mark color as present
        color_present_comb[col] = 1'b1;
      end
    end
  end

  // FSM and registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_mask <= 8'h00;
      best_count <= 4'h9;
      best_found <= 1'b0;
      min_count <= 4'h0;
      impossible <= 1'b0;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= RUN;
            current_mask <= 8'h00;
            best_count <= 4'h9;
            best_found <= 1'b0;
            done <= 1'b0;
          end
        end

        RUN: begin
          // Evaluate current_mask and update best_count/best_found if valid
          if (valid_mask && coverage_full && color_valid) begin
            if (num_in_mask < best_count) begin
              best_count <= num_in_mask;
              best_found <= 1'b1;
            end
          end
          // Update current_mask and check for completion
          current_mask <= current_mask + 8'd1;
          if (current_mask + 8'd1 == 8'd0) begin // Wrap indicates completion
            state <= DONE;
            if (best_found) begin
              min_count <= best_count;
              impossible <= 1'b0;
            end else begin
              impossible <= 1'b1;
              min_count <= 4'h0;
            end
            done <= 1'b1;
          end else begin
            state <= RUN;
          end
        end

        DONE: begin
          // Stay in DONE until reset or start
          if (start) begin
            state <= IDLE;
            done <= 1'b0;
          end
        end
      endcase
    end
  end

endmodule