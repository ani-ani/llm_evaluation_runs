module pikeman_solver (
    input clk,
    input rst_n,
    input start,
    input [31:0] t0,
    input [63:0] T,
    output reg [31:0] count,
    output reg [31:0] penalty,
    output reg done
);

// Internal registers
reg [15:0] mem [0:15];
reg [15:0] lfsr_reg;
reg [63:0] accumulated_time;
reg [31:0] current_penalty;
reg [3:0] index;
reg [2:0] state;
reg [15:0] gen_count;
reg [31:0] count_reg;
reg [31:0] penalty_reg;
reg done_reg;

// State definitions
localparam IDLE = 3'd0;
localparam GENERATE = 3'd1;
localparam SORT = 3'd2;
localparam CALCULATE = 3'd3;
localparam DONE = 3'd4;

// LFSR next state function
function automatic [15:0] next_lfsr;
   input [15:0] current;
   [1:0] feedback;
   feedback = current[2] ^ current[0];
   return {feedback[1], feedback[0], current[15:1]};
endfunction

// Sorting network function (simplified, reverses the array)
function automatic [15:0]{16'b} sort_network;
   input [15:0]{16'b} mem_array;
   [15:0] sorted;
   assign sorted[0] = mem_array[15];
   assign sorted[1] = mem_array[14];
   assign sorted[2] = mem_array[13];
   assign sorted[3] = mem_array[12];
   assign sorted[4] = mem_array[11];
   assign sorted[5] = mem_array[10];
   assign sorted[6] = mem_array[9];
   assign sorted[7] = mem_array[8];
   assign sorted[8] = mem_array[7];
   assign sorted[9] = mem_array[6];
   assign sorted[10] = mem_array[5];
   assign sorted[11] = mem_array[4];
   assign sorted[12] = mem_array[3];
   assign sorted[13] = mem_array[2];
   assign sorted[14] = mem_array[1];
   assign sorted[15] = mem_array[0];
   return sorted;
endfunction

// Combinational assignments for outputs
assign count = count_reg;
assign penalty = penalty_reg;
assign done = done_reg;

// Main sequential logic
always @(posedge clk) begin
   if (!rst_n) begin
      mem <= 16'b0;
      lfsr_reg <= 16'b0;
      accumulated_time <= 64'd0;
      current_penalty <= 32'd0;
      index <= 4'd0;
      state <= IDLE;
      gen_count <= 16'd0;
      count_reg <= 32'd0;
      penalty_reg <= 32'd0;
      done_reg <= 1'b0;
   end else begin
      case (state)
         IDLE: begin
             if (start) begin
                 state <= GENERATE;
                 gen_count <= 16'd0;
             end
         end
         GENERATE: begin
             if (gen_count == 16'd0) begin
                 mem[0] <= t0;
                 lfsr_reg <= t0;
                 gen_count <= 16'd1;
             end else if (gen_count < 16) begin
                 [15:0] next_val;
                 next_val = next_lfsr(lfsr_reg);
                 mem[gen_count] <= next_val;
                 lfsr_reg <= next_val;
                 gen_count <= gen_count + 1;
             end else begin
                 state <= SORT;
             end
         end
         SORT: begin
             state <= CALCULATE;
         end
         CALCULATE: begin
             if (index < 4'd16) begin
                 accumulated_time <= accumulated_time + mem[index];
                 if (accumulated_time <= T) begin
                     count_reg <= count_reg + 1;
                     current_penalty <= (current_penalty + accumulated_time) % 1000000007;
                     index <= index + 1;
                 end else begin
                     done_reg <= 1'b1;
                     state <= DONE;
                 end
             end else begin
                 done_reg <= 1'b1;
                 state <= DONE;
             end
         end
         DONE: begin
             // Stay in DONE
         end
      endcase
   end
end

endmodule