module tree_heap_probability(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [7:0] b1_value,
  input [2:0] p1_parent,
  input [7:0] b2_value,
  input [2:0] p2_parent,
  input [7:0] b3_value,
  input [2:0] p3_parent,
  input [7:0] b4_value,
  input [2:0] p4_parent,
  output reg [31:0] result,
  output reg done
);
  
  typedef enum logic [1:0] {IDLE, COUNT_EDGES, LUT_LOOKUP, DONE} state_t;
  state_t current_state, next_state;
  
  reg [2:0] n_reg;
  reg [2:0] p1_reg, p2_reg, p3_reg, p4_reg;
  reg [1:0] edge_count;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      n_reg <= 3'b0;
      p1_reg <= 3'b0;
      p2_reg <= 3'b0;
      p3_reg <= 3'b0;
      p4_reg <= 3'b0;
      edge_count <= 2'b0;
      result <= 32'b0;
      done <= 1'b0;
    end else begin
      current_state <= next_state;
      
      case (current_state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            n_reg <= n;
            p1_reg <= p1_parent;
            p2_reg <= p2_parent;
            p3_reg <= p3_parent;
            p4_reg <= p4_parent;
          end
        end
        
        COUNT_EDGES: begin
          edge_count <= ((1 <= n_reg) ? (p1_reg > 0) : 0) +
                       ((2 <= n_reg) ? (p2_reg > 0) : 0) +
                       ((3 <= n_reg) ? (p3_reg > 0) : 0) +
                       ((4 <= n_reg) ? (p4_reg > 0) : 0);
        end
        
        LUT_LOOKUP: begin
          case (edge_count)
            2'd0: result <= 32'd0;
            2'd1: result <= 32'd500000004;
            2'd2: result <= 32'd250000002;
            2'd3: result <= 32'd125000001;
            default: result <= 32'd0;
          endcase
        end
        
        DONE: begin
          done <= 1'b1;
        end
      endcase
    end
  end
  
  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: if (start) next_state = COUNT_EDGES;
      COUNT_EDGES: next_state = LUT_LOOKUP;
      LUT_LOOKUP: next_state = DONE;
      DONE: next_state = IDLE;
    endcase
  end
  
endmodule