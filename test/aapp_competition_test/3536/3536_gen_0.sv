module tree_heap_probability(
  input clk, // system clock
  input rst_n, // active-low reset
  input start, // pulse high to begin calculation
  input [2:0] n, // number of nodes (1-4) - not used directly in this implementation
  input [7:0] b1_value, input [2:0] p1_parent, // node 1
  input [7:0] b2_value, input [2:0] p2_parent, // node 2
  input [7:0] b3_value, input [2:0] p3_parent, // node 3
  input [7:0] b4_value, input [2:0] p4_parent, // node 4
  output reg [31:0] result, // answer modulo 1e9+7 (32 bits)
  output reg done // high when computation completes
);

  // State encoding
  localparam IDLE        = 2'b00;
  localparam COUNT_EDGES = 2'b01;
  localparam LUT_LOOKUP  = 2'b10;
  localparam DONE        = 2'b11;

  reg [1:0] state, next_state;
  reg [2:0] edge_count;

  // Sequential state and outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      edge_count <= 3'd0;
      result     <= 32'd0;
      done       <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done       <= 1'b0;
          result     <= 32'd0;
          if (start) begin
            // COUNT_EDGES is done in next cycle using non-blocking assignments
            edge_count <= 3'd0;
          end
        end

        COUNT_EDGES: begin
          // Count edges: parent_id > 0 indicates an edge
          edge_count <= {2'b00, (p1_parent > 0)} +
                        {2'b00, (p2_parent > 0)} +
                        {2'b00, (p3_parent > 0)} +
                        {2'b00, (p4_parent > 0)};
        end

        LUT_LOOKUP: begin
          // Lookup modular inverse of 2^x modulo 1e9+7 using provided map
          case (edge_count)
            3'd0: result <= 32'd0;
            3'd1: result <= 32'd500000004;
            3'd2: result <= 32'd250000002;
            3'd3: result <= 32'd125000001;
            default: result <= 32'd0;
          endcase
        end

        DONE: begin
          done <= 1'b1;
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = COUNT_EDGES;
      end

      COUNT_EDGES: begin
        next_state = LUT_LOOKUP;
      end

      LUT_LOOKUP: begin
        next_state = DONE;
      end

      DONE: begin
        // Wait for start to be deasserted to return to IDLE
        if (!start)
          next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule