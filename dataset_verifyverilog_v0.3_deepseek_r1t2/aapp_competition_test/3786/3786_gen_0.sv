module apple_tree #(
  parameter N = 16,      // Maximum number of nodes
  parameter DATA_WIDTH = 4 // Bit width for node indices (1-16)
) (
  input clk,
  input rst_n,
  input start,
  input load,           // Load signal for parent input
  input [DATA_WIDTH-1:0] parent,   // Parent of current node (1-based)
  output reg [DATA_WIDTH-1:0] result,
  output reg done
);
  // State declarations
  localparam [2:0] IDLE = 3'd0;
  localparam [2:0] INIT = 3'd1;
  localparam [2:0] LOAD_ST = 3'd2;
  localparam [2:0] DONE_ST = 3'd3;
  
  reg [2:0] state;
  reg [DATA_WIDTH-1:0] depth_mem [0:N-1];   // Depth storage for each node
  reg parity_mem [0:15];         // Parity storage for depths 0-15
  reg [DATA_WIDTH-1:0] total;    // Total apples collected
  reg [DATA_WIDTH-1:0] idx;      // Current node index (0 to N-1)
  
  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result <= {DATA_WIDTH{1'b0}};
      total <= {DATA_WIDTH{1'b0}};
      idx <= {DATA_WIDTH{1'b0}};
      for (i = 0; i < N; i = i + 1) begin
        depth_mem[i] <= {DATA_WIDTH{1'b0}};
      end
      for (i = 0; i < 16; i = i + 1) begin
        parity_mem[i] <= 1'b0;
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            depth_mem[0] <= {DATA_WIDTH{1'b0}};
            parity_mem[0] <= ~parity_mem[0];
            total <= parity_mem[0] ? {DATA_WIDTH{1'b1}} : {DATA_WIDTH{1'b0}};
            idx <= 4'd1;
            state <= INIT;
          end
        end
        
        INIT: begin
          state <= LOAD_ST;
        end
        
        LOAD_ST: begin
          if (load && (idx < N)) begin
            depth_mem[idx] <= depth_mem[parent-1] + 4'd1;
            parity_mem[depth_mem[parent-1] + 4'd1] <= 
              ~parity_mem[depth_mem[parent-1] + 4'd1];
            total <= parity_mem[depth_mem[parent-1] + 4'd1] ? 
              total - 4'd1 : total + 4'd1;
            idx <= idx + 4'd1;
            if (idx == N-1) begin
              state <= DONE_ST;
            end
          end else if (idx >= N) begin
            state <= DONE_ST;
          end
        end
        
        DONE_ST: begin
          result <= total;
          done <= 1'b1;
          state <= IDLE;
        end
        
        default: begin
          state <= IDLE;
        end
      endcase
    end
  end
endmodule