module apple_tree #(
  parameter N = 16,
  parameter DATA_WIDTH = 4
) (
  input wire clk,
  input wire rst_n,
  input wire start,
  input wire load,
  input wire [DATA_WIDTH-1:0] parent,
  output reg [DATA_WIDTH-1:0] result,
  output reg done
);

  // State declarations
  localparam [2:0] IDLE  = 3'd0;
  localparam [2:0] INIT  = 3'd1;
  localparam [2:0] LOAD  = 3'd2;
  localparam [2:0] DONE  = 3'd3;

  // Internal registers
  reg [2:0] state;
  reg [DATA_WIDTH-1:0] depth_mem [0:N-1];
  reg parity_mem [0:15];
  reg signed [DATA_WIDTH-1:0] total;
  reg [DATA_WIDTH-1:0] idx;
  reg [DATA_WIDTH-1:0] current_depth;
  reg signed [DATA_WIDTH-1:0] new_total;
  integer i;
  reg update_done;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result <= {DATA_WIDTH{1'b0}};
      total <= {DATA_WIDTH{1'b0}};
      idx <= {DATA_WIDTH{1'b0}};
      current_depth <= {DATA_WIDTH{1'b0}};
      new_total <= {DATA_WIDTH{1'b0}};
      update_done <= 1'b0;
      // Initialize parity memory
      for (i = 0; i < 16; i = i + 1) begin
        parity_mem[i] <= 1'b0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            // Initialize depth memory to 0
            for (i = 0; i < N; i = i + 1) begin
              depth_mem[i] <= {DATA_WIDTH{1'b0}};
            end
            // Initialize root node (node 1)
            depth_mem[0] <= {DATA_WIDTH{1'b0}};
            current_depth <= {DATA_WIDTH{1'b0}};
            update_done <= 1'b0;
            state <= INIT;
            done <= 1'b0;
          end else begin
            done <= 1'b0;
          end
        end

        INIT: begin
          // Update parity for depth 0
          if (update_done == 1'b0) begin
            parity_mem[current_depth] <= ~parity_mem[current_depth];
            if (parity_mem[current_depth] == 1'b0) begin
              total <= total + 1;
            end else begin
              total <= total - 1;
            end
            update_done <= 1'b1;
          end else begin
            // Set up for loading other nodes
            idx <= {DATA_WIDTH{1'b0}} + 1; // Start at node 2 (index 1)
            update_done <= 1'b0;
            state <= LOAD;
          end
        end

        LOAD: begin
          if (load && idx < N) begin
            // Compute depth for current node
            current_depth <= depth_mem[parent-1] + 1;
            update_done <= 1'b0;
            state <= LOAD;
          end else if (load && idx >= N) begin
            // All nodes processed
            result <= total;
            done <= 1'b1;
            state <= DONE;
          end else if (!load && idx < N) begin
            // Waiting for load signal
            state <= LOAD;
          end else begin
            // Default case when not loading and idx >= N
            result <= total;
            done <= 1'b1;
            state <= DONE;
          end
        end

        DONE: begin
          // Hold result and done
          done <= 1'b1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

  // Combinational logic for depth update in LOAD state
  always @(*) begin
    if (state == LOAD && load && idx < N && update_done == 1'b0) begin
      // Update parity for new depth
      if (parity_mem[current_depth] == 1'b0) begin
        new_total = total + 1;
      end else begin
        new_total = total - 1;
      end
    end else begin
      new_total = total;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset handled above
    end else begin
      if (state == LOAD && load && idx < N && update_done == 1'b0) begin
        // Update depth memory for current node
        depth_mem[idx] <= current_depth;
        // Update parity memory
        parity_mem[current_depth] <= ~parity_mem[current_depth];
        // Update total
        total <= new_total;
        // Move to next node
        idx <= idx + 1;
        update_done <= 1'b1;
      end else if (state == LOAD && update_done == 1'b1) begin
        update_done <= 1'b0;
        // Check if we need to finish
        if (idx >= N) begin
          result <= total;
          done <= 1'b1;
          state <= DONE;
        end
      end
    end
  end

endmodule