module fair_ranking_solver (
input clk,
input rst_n, // active-low reset
input start,
input [2:0] n,
input [2:0] k,
input [7:0] adj_matrix [0:7][0:7],
input [7:0] s_mask,
output reg [2:0] min_disqualify_size,
output reg found,
output reg impossible
);

// Registers
reg [2:0] current_size;
reg [7:0] subset_counter;
reg [7:0] available_players;
reg [2:0] min_size;
reg [7:0] total_removed;
reg [7:0] subset_candidate;
reg [2:0] in_degree_reg [0:7]; // in-degrees for each node
reg [2:0] count_processed;
reg [2:0] total_nodes;
reg [3:0] state; // 4 bits for state encoding
localparam IDLE = 4'd0;
localparam INIT = 4'd1;
localparam CHECK_SIZE = 4'd2;
localparam GENERATE_SUBSETS = 4'd3;
localparam VERIFY_GRAPH = 4'd4;
localparam WAIT_ACYCLE = 4'd5;
localparam NEXT_SUBSET = 4'd6;
localparam CHECK_NEXT_SIZE = 4'd7;
localparam DONE = 4'd8;
localparam IMPOSSIBLE = 4'd9;

// Compute available_players (combinational)
assign available_players = ~s_mask & ((1<<n) -1);

// Popcount function
function automatic int popcount_input [7:0] pc;
   return (pc[7] + pc[6] + pc[5] + pc[4] + pc[3] + pc[2] + pc[1] + pc[0]);
endfunction

// Default assignments and state machine
always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      current_size <= 3'd0;
      subset_counter <= 8'd0;
      min_size <= 3'd0;
      found <= 1'b0;
      impossible <= 1'b0;
      for (int i=0; i<8; i++) in_degree_reg[i] <= 3'd0;
      count_processed <= 3'd0;
      total_nodes <= 3'd0;
      state <= IDLE;
   end else begin
      case (state)
         IDLE: begin
            if (start) state <= INIT;
         end
         INIT: begin
            current_size <= 3'd0;
            subset_counter <= 8'd0;
            min_size <= 3'd0;
            found <= 1'b0;
            impossible <= 1'b0;
            for (int i=0; i<8; i++) in_degree_reg[i] <= 3'd0;
            count_processed <= 3'd0;
            total_nodes <= 3'd0;
            state <= CHECK_SIZE;
         end
         CHECK_SIZE: begin
            if (current_size < k) begin
               int available_count = popcount_input(available_players);
               if (available_count >= current_size) begin
                  state <= GENERATE_SUBSETS;
               end else begin
                  current_size <= current_size + 1;
                  state <= CHECK_SIZE;
               end
            end else begin
               impossible <= 1'b1;
               state <= DONE;
            end
         end
         GENERATE_SUBSETS: begin
            if (subset_counter < (1<<n)) begin
               subset_candidate = subset_counter & available_players;
               int sub_size = popcount_input(subset_candidate);
               if (sub_size == current_size) begin
                  total_removed = s_mask | subset_candidate;
                  total_removed = total_removed & ((1<<n)-1);
                  int rem_players = ~total_removed & ((1<<n)-1);
                  total_nodes = popcount_input(rem_players);
                  count_processed <= 3'd0;
                  // Dummy: assume acyclic for example
                  state <= WAIT_ACYCLE;
               end else begin
                  subset_counter <= subset_counter + 1;
                  state <= GENERATE_SUBSETS;
               end
            end else begin
               state <= CHECK_NEXT_SIZE;
            end
         end
         WAIT_ACYCLE: begin
            if (1) begin
               if (1) begin
                  found <= 1'b1;
                  min_size <= current_size;
                  state <= DONE;
               end else begin
                  subset_counter <= subset_counter + 1;
                  state <= GENERATE_SUBSETS;
               end
            end
         end
         CHECK_NEXT_SIZE: begin
            current_size <= current_size + 1;
            subset_counter <= 8'd0;
            state <= GENERATE_SUBSETS;
         end
         DONE: begin
            min_disqualify_size <= min_size;
            state <= DONE;
         end
         IMPOSSIBLE: begin
            impossible <= 1'b1;
            state <= IMPOSSIBLE;
         end
         default: state <= IDLE;
      endcase
   end
endmodule