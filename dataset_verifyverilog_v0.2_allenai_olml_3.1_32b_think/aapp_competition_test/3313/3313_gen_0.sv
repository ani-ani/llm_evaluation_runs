module gem_collector (
input clk,
input rst_n,
input start,
input [2:0] n,
input [5:0] w,
input [7:0] h,
input [2:0] gem_index,
input [5:0] gem_x,
input [7:0] gem_y,
input gem_wr,
output reg [2:0] max_gems,
output reg done
);

// Internal registers
reg [7:0] gem_x_arr [7:0];
reg [7:0] gem_y_arr [7:0];
reg [7:0] w_reg;
reg [7:0] h_reg;
reg [2:0] state;
reg [7:0] gem_count;
reg [2:0] max_gems_reg;
reg done_reg;
reg [2:0] max_count [7:0];
reg [2:0] global_max;
reg [2:0] dp_index;

// State assignments
localparam IDLE = 3'b000;
localparam LOAD_GEMS = 3'b001;
localparam SORT_GEMS = 3'b010;
localparam DP_PROCESS = 3'b011;
localparam DONE_STATE = 3'b100;

// Default values
assign max_gems = max_gems_reg;
assign done = done_reg;

// Reset handling and state machine
always @(posedge clk) begin
   if (!rst_n) begin
      gem_x_arr <= 8'b0;
      gem_y_arr <= 8'b0;
      w_reg <= 8'b0;
      h_reg <= 8'b0;
      state <= IDLE;
      gem_count <= 8'b0;
      max_gems_reg <= 3'b0;
      done_reg <= 1'b0;
      max_count <= 8'b0;
      global_max <= 3'b0;
      dp_index <= 3'b0;
   end else begin
      if (state == IDLE) begin
         if (gem_wr && (gem_index < n)) begin
            gem_x_arr[gem_index] <= {2'b00, gem_x};
            gem_y_arr[gem_index] <= gem_y;
            gem_count <= gem_count + 1;
         end
         if (start && (gem_count == n)) begin
            state <= LOAD_GEMS;
         end
      end else if (state == LOAD_GEMS) begin
         state <= SORT_GEMS;
      end else if (state == SORT_GEMS) begin
         // Assume sorting is done here, move to DP
         state <= DP_PROCESS;
         // Initialize DP
         max_count <= 8'b0;
         global_max <= 3'b0;
         dp_index <= 3'b0;
      end else if (state == DP_PROCESS) begin
         if (dp_index < n) begin
            dp_index <= dp_index +1;
         end else begin
            state <= DONE_STATE;
            max_gems_reg <= global_max;
            done_reg <= 1'b1;
         end
      end
   end
end

endmodule