module newman_prime (
   input clk,
   input rst_n,
   input start,
   input [3:0] n,
   output reg [15:0] result,
   output reg done
);

reg [1:0] state;
reg [3:0] n_val;
reg [31:0] prev, curr;
reg [3:0] counter;
reg start_edge;
parameter IDLE = 2'b00;
parameter PROCESSING = 2'b01;
parameter DONE_STATE = 2'b10;

always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      state <= IDLE;
      n_val <=4'b0;
      prev <=32'h0;
      curr <=32'h0;
      counter <=4'b0;
      result <=16'b0;
      done <=1'b0;
      start_edge <=1'b0;
   end else begin
      start_edge <= (start && !start_edge);
      case (state)
         IDLE: begin
            if (start_edge) begin
               n_val <= n;
               if (n_val ==4'b0 || n_val ==4'b1) begin
                  result <=16'b1;
                  done <=1'b1;
                  state <= DONE_STATE;
               end else begin
                  prev <=32'h1;
                  curr <=32'h1;
                  counter <=4'b0;
                  state <= PROCESSING;
               end
            end
         end

         PROCESSING: begin
            if (counter < n_val -1) begin
               prev <= curr;
               curr <= 2 * curr + prev;
               counter <= counter +1;
            end else begin
               result <= curr[15:0];
               done <=1'b1;
               state <= DONE_STATE;
            end
         end

         DONE_STATE: begin
            if (!start) begin
               state <= IDLE;
            end
         end

      endcase
   end
end
endmodule