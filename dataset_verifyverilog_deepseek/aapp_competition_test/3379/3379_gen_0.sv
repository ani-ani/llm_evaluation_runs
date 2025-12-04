module max_kahn_sources(
  input clk,
  input rst_n,
  input start,
  input [2:0] num_nodes,
  input [5:0] num_edges,
  input [2:0] edge_src [0:55],
  input [2:0] edge_dst [0:55],
  output reg [3:0] max_S_size,
  output reg done
);

localparam IDLE = 2'd0;
localparam INIT = 2'd1;
localparam PROCESS = 2'd2;
localparam DONE = 2'd3;

reg [1:0] state;
reg [5:0] edge_ptr;
reg [7:0] adj_matrix [0:7];
reg [3:0] in_degree [0:7];
reg [7:0] S;
reg [3:0] current_max;

function [2:0] prio_enc(input [7:0] bits);
  casez(bits)
    8'b???????1: prio_enc = 3'd0;
    8'b??????10: prio_enc = 3'd1;
    8'b?????100: prio_enc = 3'd2;
    8'b????1000: prio_enc = 3'd3;
    8'b???10000: prio_enc = 3'd4;
    8'b??100000: prio_enc = 3'd5;
    8'b?1000000: prio_enc = 3'd6;
    8'b10000000: prio_enc = 3'd7;
    default: prio_enc = 3'd0;
  endcase
endfunction

wire [2:0] current_node = prio_enc(S);
wire [7:0] neighbor_mask = adj_matrix[current_node];
wire [7:0] degree_eq1;
genvar j;
generate
  for (j=0; j<8; j=j+1) begin
    assign degree_eq1[j] = (in_degree[j] == 4'd1);
  end
endgenerate

wire [7:0] add_nodes = neighbor_mask & degree_eq1;
wire [7:0] next_S = (S & ~(8'd1 << current_node)) | add_nodes;
wire [3:0] next_S_size = $countones(next_S);

reg [3:0] next_in_degree [0:7];
generate
  for (j=0; j<8; j=j+1) begin
    assign next_in_degree[j] = neighbor_mask[j] ? (in_degree[j] - 4'd1) : in_degree[j];
  end
endgenerate

wire update_max = (next_S_size > current_max);

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 1'b0;
    max_S_size <= 0;
    edge_ptr <= 0;
    S <= 0;
    current_max <= 0;
    for (int i=0; i<8; i=i+1) begin
      adj_matrix[i] <= 0;
      in_degree[i] <= 0;
    end
  end else begin
    case(state)
      IDLE: begin
        if (start) begin
          state <= INIT;
          edge_ptr <= 0;
          current_max <= 0;
          S <= 0;
          for (int i=0; i<8; i=i+1) begin
            adj_matrix[i] <= 0;
            in_degree[i] <= 0;
          end
        end
      end
      INIT: begin
        if (edge_ptr < num_edges) begin
          adj_matrix[edge_src[edge_ptr]] <= adj_matrix[edge_src[edge_ptr]] | (8'd1 << edge_dst[edge_ptr]);
          in_degree[edge_dst[edge_ptr]] <= in_degree[edge_dst[edge_ptr]] + 1;
          edge_ptr <= edge_ptr + 1;
        end else begin
          S <= 0;
          for (int i=0; i<8; i=i+1) begin
            if (i < num_nodes && in_degree[i] == 0) S[i] <= 1'b1;
          end
          current_max <= $countones(S);
          state <= PROCESS;
        end
      end
      PROCESS: begin
        if (S != 0) begin
          S <= next_S;
          for (int k=0; k<8; k=k+1) in_degree[k] <= next_in_degree[k];
          if (update_max) current_max <= next_S_size;
        end else begin
          max_S_size <= current_max;
          done <= 1'b1;
          state <= DONE;
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

endmodule