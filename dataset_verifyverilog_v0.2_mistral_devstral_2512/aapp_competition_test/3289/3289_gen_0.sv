module optimal_cluster (
  input clk,
  input rst_n,
  input start,
  input [7:0] a_i [0:7],
  input [7:0] b_i [0:7],
  input [0:7] c_i,
  output reg [7:0] cluster_size,
  output reg done
);

  // Define states
  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] PROCESSING = 2'b01;
  localparam [1:0] DONE = 2'b10;

  reg [1:0] state = IDLE;
  reg [7:0] ordering = 0;
  reg [7:0] min_cluster = 8'b11111111; // Initialize to max value

  // Pre-defined S and T values in Q8.8 format
  reg [15:0] S_vals [0:3] = '{16'd256, 16'd512, 16'd128, 16'd384}; // 1.0, 0.5, -1.0, -0.5
  reg [15:0] T_vals [0:3] = '{16'd256, 16'd512, 16'd128, 16'd384}; // 1.0, 0.5, -1.0, -0.5

  // Compute scores for current ordering
  reg [15:0] scores [0:7];
  reg [2:0] sorted_indices [0:7];
  reg [7:0] first_idx, last_idx;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      ordering <= 0;
      min_cluster <= 8'b11111111;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESSING;
            ordering <= 0;
            min_cluster <= 8'b11111111;
            done <= 0;
          end
        end
        PROCESSING: begin
          // Compute scores for current ordering
          for (int i = 0; i < 8; i = i + 1) begin
            reg [1:0] S_idx = ordering[(2*i)+1:2*i];
            reg [1:0] T_idx = ordering[(2*i)+1:2*i]; // Same for simplicity
            scores[i] = ($signed(a_i[i]) * $signed(S_vals[S_idx])) + ($signed(b_i[i]) * $signed(T_vals[T_idx]));
          end

          // Sort indices based on scores (bubble sort for simplicity)
          for (int i = 0; i < 8; i = i + 1) begin
            sorted_indices[i] = i;
          end
          for (int i = 0; i < 7; i = i + 1) begin
            for (int j = 0; j < 7 - i; j = j + 1) begin
              if (scores[sorted_indices[j]] > scores[sorted_indices[j+1]]) begin
                reg [2:0] temp = sorted_indices[j];
                sorted_indices[j] = sorted_indices[j+1];
                sorted_indices[j+1] = temp;
              end
            end
          end

          // Find first and last c_i=1 in sorted order
          first_idx = 8'b11111111;
          last_idx = 0;
          for (int i = 0; i < 8; i = i + 1) begin
            if (c_i[sorted_indices[i]]) begin
              if (first_idx == 8'b11111111) first_idx = i;
              last_idx = i;
            end
          end

          // Calculate cluster size
          reg [7:0] current_cluster = (first_idx == 8'b11111111) ? 0 : (last_idx - first_idx + 1);

          // Update min_cluster
          if (current_cluster < min_cluster) begin
            min_cluster = current_cluster;
          end

          // Move to next ordering
          ordering = ordering + 1;
          if (ordering == 255) begin
            state <= DONE;
            cluster_size <= min_cluster;
            done <= 1;
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