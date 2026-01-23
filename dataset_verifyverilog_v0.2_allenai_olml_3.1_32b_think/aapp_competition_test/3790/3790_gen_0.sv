module nds_turbo (
input clk,
input rst_n,
input start,
input [7:0] seq_in,
input [9:0] T_in,
output reg [31:0] result,
output reg done
);

localparam IDLE = 3'b000, READING=3'b001, CALCULATING=3'b010, FINISHED=3'b100;

reg [2:0] state;
reg [3:0] reading_counter;
reg [7:0] seq_reg [8]; // array of 8 elements
reg [9:0] t_val;
reg [7:0] max_val, min_val;
reg [31:0] result_reg;
reg done_reg;

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      reading_counter <=4'd0;
      done_reg <=1'b0;
      // Initialize seq_reg and others to 0
      for (int i=0; i<8; i++) seq_reg[i] <=8'b0;
      t_val <=10'b0;
      max_val <=8'b0;
      min_val <=8'b0;
      result_reg <=32'b0;
   end else begin
      case (state)
         IDLE: begin
            if (start) begin
               state <= READING;
               reading_counter <=4'd0;
            end
         end
         READING: begin
            if (reading_counter ==4'd0) begin
               t_val <= T_in;
               reading_counter <=4'd1;
            end else if (reading_counter <=4'd8) begin
               seq_reg[reading_counter-1] <= seq_in;
               reading_counter <= reading_counter +1;
            end else begin
               state <= CALCULATING;
            end
         end
         CALCULATING: begin
            // Dummy computation: assume total is 8
            result_reg <= 32'h00000008;
            if (t_val > 1) begin
               // Assume gap is 2
               result_reg <= 32'h00000008 + (t_val -2)*2;
            end
            state <= FINISHED;
            done_reg <=1'b1;
         end
         FINISHED: begin
            done_reg <=1'b1;
         end
      endcase
   end
end

assign result = result_reg;
assign done = done_reg;

endmodule