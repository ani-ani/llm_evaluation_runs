module max_independent_set (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_nodes,
  input [7:0] num_edges,
  input [2:0] edge_a [0:7],
  input [2:0] edge_b [0:7],
  output reg [3:0] result,
  output reg done
);

  // State definitions
  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] PROCESSING = 2'b01;
  localparam [1:0] DONE = 2'b10;

  reg [1:0] state = IDLE;
  reg [7:0] mask = 0;
  reg [3:0] max_size = 0;
  reg [3:0] current_size = 0;
  reg [3:0] edge_idx = 0;
  reg valid_subset = 1;
  reg independent = 1;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      mask <= 0;
      max_size <= 0;
      current_size <= 0;
      edge_idx <= 0;
      valid_subset <= 1;
      independent <= 1;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESSING;
            mask <= 0;
            max_size <= 0;
            done <= 0;
          end
        end

        PROCESSING: begin
          // Check if current mask is valid (only vertices < num_nodes)
          valid_subset <= (mask & ~((1 << num_nodes) - 1)) == 0;

          // Check independence for all edges
          independent <= 1;
          for (edge_idx = 0; edge_idx < num_edges; edge_idx = edge_idx + 1) begin
            if (mask[edge_a[edge_idx]] && mask[edge_b[edge_idx]]) begin
              independent <= 0;
            end
          end

          // Count bits in mask
          current_size = 0;
          for (int i = 0; i < 8; i = i + 1) begin
            if (mask[i]) current_size = current_size + 1;
          end

          // Update max_size if valid and independent
          if (valid_subset && independent && (current_size > max_size)) begin
            max_size <= current_size;
          end

          // Move to next mask
          if (mask == 255) begin
            state <= DONE;
            result <= max_size;
            done <= 1;
          end else begin
            mask <= mask + 1;
          end
        end

        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule