module apple_collector (
  input clk,
  input rst_n,
  input start,
  input [3:0] p_addr,
  input [3:0] p_data,
  input p_write,
  output reg [3:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CALC_DEPTH,
    COUNT_LAYER,
    SUM_PARITY,
    DONE
  } state_t;

  state_t state;
  reg [3:0] node_counter; // Tracks current node being processed
  reg [3:0] depth_counter; // Tracks current depth being processed
  reg [3:0] count_counter; // Tracks current count being processed
  reg [3:0] temp_depth; // Temporary storage for depth calculation
  reg [3:0] temp_count; // Temporary storage for count calculation
  reg [3:0] temp_node; // Temporary storage for node index

  // Parent memory (15 entries for nodes 2..16)
  reg [3:0] parent_mem [0:14];

  // Depth memory (16 entries for nodes 1..16, index 0 unused)
  reg [3:0] depth_mem [0:15];

  // Count memory (8 entries for depths 0..7)
  reg [3:0] count_mem [0:7];

  // Initialize state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      node_counter <= 4'd0;
      depth_counter <= 4'd0;
      count_counter <= 4'd0;
      temp_depth <= 4'd0;
      temp_count <= 4'd0;
      temp_node <= 4'd0;
      result <= 4'd0;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CALC_DEPTH;
            node_counter <= 4'd1; // Start with node 2
            depth_mem[0] <= 4'd0; // Depth of root (node 1) is 0
          end
        end

        CALC_DEPTH: begin
          if (node_counter < 4'd15) begin
            temp_node <= node_counter + 4'd1; // Current node (2..16)
            temp_depth <= 4'd0;
            // Calculate depth by traversing up to root
            temp_node <= parent_mem[node_counter];
            while (temp_node != 4'd1) begin
              temp_depth <= temp_depth + 4'd1;
              temp_node <= parent_mem[temp_node - 4'd2]; // Adjust index for parent_mem
            end
            depth_mem[node_counter + 4'd1] <= temp_depth;
            node_counter <= node_counter + 4'd1;
          end else begin
            state <= COUNT_LAYER;
            depth_counter <= 4'd0;
          end
        end

        COUNT_LAYER: begin
          if (depth_counter < 4'd8) begin
            temp_count <= 4'd0;
            for (int i = 1; i < 16; i = i + 1) begin
              if (depth_mem[i] == depth_counter) begin
                temp_count <= temp_count + 4'd1;
              end
            end
            count_mem[depth_counter] <= temp_count;
            depth_counter <= depth_counter + 4'd1;
          end else begin
            state <= SUM_PARITY;
            count_counter <= 4'd0;
            result <= 4'd0;
          end
        end

        SUM_PARITY: begin
          if (count_counter < 4'd8) begin
            if (count_mem[count_counter] % 2 == 1) begin
              result <= result + 4'd1;
            end
            count_counter <= count_counter + 4'd1;
          end else begin
            state <= DONE;
            done <= 1'b1;
          end
        end

        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 1'b0;
          end
        end
      endcase
    end
  end

  // Parent memory write logic
  always @(posedge clk) begin
    if (p_write && p_addr < 4'd15) begin
      parent_mem[p_addr] <= p_data;
    end
  end

endmodule