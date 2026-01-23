module array_debug (
   input clk,
   input rst_n,
   input start,
   input [5:0] k_val,
   input [5:0] q_val,
   input [5:0] update_val,
   input update_valid,
   input [5:0] query_l,
   input [5:0] query_r,
   input query_valid,
   output reg [31:0] result,
   output reg done,
   output reg ready_for_update,
   output reg ready_for_query
);

// Registers
reg [5:0] k_val_reg;
reg [5:0] q_val_reg;
reg [5:0] update_count;
reg [5:0] update_index;
reg [31:0] seq [63:0];
reg [31:0] P [63:0];
reg [3:0] state_reg;
reg [31:0] result_reg;
reg done_reg;
reg [5:0] query_count;
reg [5:0] updates_array [0:31];

// State parameters
localparam IDLE = 4'd0,
        COLLECT_UPDATES = 4'd1,
        PROCESS_UPDATES = 4'd2,
        BUILD_PREFIX = 4'd3,
        COLLECT_QUERIES = 4'd4,
        DONE = 4'd5;

// Assign outputs
assign ready_for_update = (state_reg == COLLECT_UPDATES) && (update_count > 0);
assign ready_for_query = (state_reg == COLLECT_QUERIES) && (query_count > 0);
assign done = done_reg;
assign result = result_reg;

// Main state machine
always @(posedge clk) begin
   if (!rst_n) begin
      k_val_reg <= 6'b0;
      q_val_reg <= 6'b0;
      update_count <= 6'b0;
      update_index <= 6'b0;
      state_reg <= IDLE;
      query_count <= 6'b0;
      done_reg <= 1'b0;
      seq <= 64'b0;
      P <= 64'b0;
      updates_array <= 32{6'b0};
   end else begin
      if (state_reg == IDLE) begin
          if (start) begin
              k_val_reg <= k_val;
              q_val_reg <= q_val;
              update_count <= k_val_reg;
              update_index <= 6'b0;
              query_count <= q_val_reg;
              if (k_val_reg > 0 || q_val_reg >0) begin
                  if (k_val_reg >0) begin
                      state_reg <= COLLECT_UPDATES;
                  end else if (q_val_reg >0) begin
                      state_reg <= BUILD_PREFIX;
                  end else begin
                      state_reg <= DONE;
                  end
              end else begin
                  state_reg <= DONE;
              end
          end
      end else if (state_reg == COLLECT_UPDATES) begin
          if (update_valid && ready_for_update) begin
              updates_array[update_index] <= update_val;
              update_index <= update_index + 1;
              update_count <= update_count - 1;
          end
          if (update_count == 0) begin
              state_reg <= PROCESS_UPDATES;
          end
      end else if (state_reg == PROCESS_UPDATES) begin
          state_reg <= BUILD_PREFIX;
      end else if (state_reg == BUILD_PREFIX) begin
          if (q_val_reg >0) begin
              state_reg <= COLLECT_QUERIES;
          end else begin
              state_reg <= DONE;
          end
      end else if (state_reg == COLLECT_QUERIES) begin
          if (query_valid && ready_for_query) begin
              result_reg <= 32'd0;
              query_count <= query_count -1;
          end
          if (query_count ==0) begin
              state_reg <= DONE;
              done_reg <= 1'b1;
          end
      end else if (state_reg == DONE) begin
          done_reg <= 1'b1;
      end
   end
end

endmodule