module dsu (
  input clk, rst_n, start,
  input op_type,  // 0: union, 1: query
  input [2:0] a, b,
  output reg done,
  output reg result
);

  // State definitions
  localparam [2:0] IDLE = 3'd0;
  localparam [2:0] FIND_A_READ = 3'd1;
  localparam [2:0] FIND_A_CHECK = 3'd2;
  localparam [2:0] FIND_B_READ = 3'd3;
  localparam [2:0] FIND_B_CHECK = 3'd4;
  localparam [2:0] UNION = 3'd5;
  localparam [2:0] QUERY = 3'd6;
  localparam [2:0] DONE = 3'd7;

  // Registers
  reg [2:0] state;
  reg [2:0] curr_a, curr_b;
  reg [2:0] root_a, root_b;
  reg [2:0] parent_a, parent_b;
  reg op_type_reg;
  reg [2:0] a_reg, b_reg;
  
  // DSU arrays (8 elements, 3-bit parent, 2-bit rank)
  reg [2:0] parent [0:7];
  reg [1:0] rank [0:7];

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset: initialize all elements as their own parent, rank 0
      integer i;
      for (i = 0; i < 8; i = i + 1) begin
        parent[i] <= i;
        rank[i] <= 2'd0;
      end
      state <= IDLE;
      done <= 1'b0;
      result <= 1'b0;
    end else begin
      done <= 1'b0; // Default: done is low unless in DONE state
      case (state)
        IDLE: begin
          if (start) begin
            op_type_reg <= op_type;
            a_reg <= a;
            b_reg <= b;
            curr_a <= a;
            curr_b <= b;
            state <= FIND_A_READ;
          end
        end

        FIND_A_READ: begin
          parent_a <= parent[curr_a];
          state <= FIND_A_CHECK;
        end

        FIND_A_CHECK: begin
          if (parent_a == curr_a) begin
            root_a <= curr_a;
            curr_b <= b_reg;  // Prepare for b find
            state <= FIND_B_READ;
          end else begin
            curr_a <= parent_a;
            state <= FIND_A_READ;
          end
        end

        FIND_B_READ: begin
          parent_b <= parent[curr_b];
          state <= FIND_B_CHECK;
        end

        FIND_B_CHECK: begin
          if (parent_b == curr_b) begin
            root_b <= curr_b;
            if (op_type_reg == 1'b1)  // Query
              state <= QUERY;
            else
              state <= UNION;
          end else begin
            curr_b <= parent_b;
            state <= FIND_B_READ;
          end
        end

        UNION: begin
          if (root_a != root_b) begin
            if (rank[root_a] < rank[root_b])
              parent[root_a] <= root_b;
            else if (rank[root_a] > rank[root_b])
              parent[root_b] <= root_a;
            else begin
              parent[root_b] <= root_a;
              rank[root_a] <= rank[root_a] + 2'd1;
            end
          end
          state <= DONE;
        end

        QUERY: begin
          result <= (root_a == root_b) ? 1'b1 : 1'b0;
          state <= DONE;
        end

        DONE: begin
          done <= 1'b1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end
endmodule