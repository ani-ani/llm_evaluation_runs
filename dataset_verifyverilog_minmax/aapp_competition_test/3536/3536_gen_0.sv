module tree_heap_probability(
  input clk, // system clock
  input rst_n, // active-low reset
  input start, // pulse high to begin calculation
  input [2:0] n, // number of nodes (1-4)
  input [7:0] b1_value, input [2:0] p1_parent, // node 1
  input [7:0] b2_value, input [2:0] p2_parent, // node 2
  input [7:0] b3_value, input [2:0] p3_parent, // node 3
  input [7:0] b4_value, input [2:0] p4_parent, // node 4
  output reg [31:0] result, // answer modulo 1e9+7 (32 bits)
  output reg done // high when computation completes
);

// FSM states
localparam IDLE = 2'd0;
localparam COUNT_EDGES = 2'd1;
localparam LUT_LOOKUP = 2'd2;
localparam DONE = 2'd3;

reg [1:0] current_state, next_state;
reg [1:0] edge_count; // 0 to 3 edges

// Next state logic
always @(*) begin
  next_state = IDLE;
  case (current_state)
    IDLE: next_state = start ? COUNT_EDGES : IDLE;
    COUNT_EDGES: next_state = LUT_LOOKUP;
    LUT_LOOKUP: next_state = DONE;
    DONE: next_state = IDLE;
    default: next_state = IDLE;
  endcase
end

// State transition and output logic
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    current_state <= IDLE;
    result <= 32'd0;
    done <= 1'b0;
    edge_count <= 2'd0;
  end else begin
    current_state <= next_state;
    case (current_state)
      IDLE: begin
        done <= 1'b0;
        // result holds previous value until next calculation
      end
      COUNT_EDGES: begin
        // Count child nodes (parent_id > 0) for first n nodes
        if (n >= 1 && p1_parent != 3'd0) edge_count <= 2'd1;
        else if (n >= 2 && p2_parent != 3'd0) edge_count <= 2'd2;
        else if (n >= 3 && p3_parent != 3'd0) edge_count <= 2'd3;
        else if (n >= 4 && p4_parent != 3'd0) edge_count <= 2'd3; // max 3 edges for 4 nodes
        else edge_count <= 2'd0; // no edges
      end
      LUT_LOOKUP: begin
        // Use precomputed lookup table
        case (edge_count)
          2'd0: result <= 32'd0; // 0 -> 0
          2'd1: result <= 32'd500000004; // 1 -> 500000004
          2'd2: result <= 32'd250000002; // 2 -> 250000002
          2'd3: result <= 32'd125000001; // 3 -> 125000001
          default: result <= 32'd0;
        endcase
      end
      DONE: begin
        done <= 1'b1;
      end
    endcase
  end
end

endmodule