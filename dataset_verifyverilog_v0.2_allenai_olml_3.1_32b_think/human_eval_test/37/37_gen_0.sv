module sort_even (
   input clk,
   input rst_n, // active-low reset
   input start,
   input [7:0] data_in [0:7], // input array of 8 elements, each 8-bit signed
   output reg [7:0] data_out [0:7], // output array
   output reg done
);

localparam IDLE = 0,
READ = 1,
SORT_EVEN = 2,
WRITE =3,
DONE =4;

reg [7:0] data_buf [0:7];
reg [2:0] state;
reg [3:0] sort_step;

always @(posedge clk or posedge rst_n) begin
   if (!rst_n) begin
      state <= IDLE;
      data_buf <= 'b0;
      sort_step <=0;
      done <=0;
   end else begin
      case(state)
         IDLE: begin
             if (start) begin
                 state <= READ;
             end else begin
                 state <= IDLE;
             end
         end
         READ: begin
             data_buf <= data_in;
             state <= SORT_EVEN;
         end
         SORT_EVEN: begin
             if (sort_step < 9) begin
                 integer current_step = sort_step;
                 sort_step <= current_step +1;
                 integer pass = current_step /3;
                 integer comp_in_pass = current_step %3;
                 integer idx1 = 2 * comp_in_pass;
                 integer idx2 = 2 * (comp_in_pass +1);
                 if (data_buf[idx1] > data_buf[idx2]) begin
                     data_buf[idx1] <= data_buf[idx2];
                     data_buf[idx2] <= data_buf[idx1];
                 end
             end else begin
                 state <= WRITE;
             end
         end
         WRITE: begin
             data_out <= data_buf;
             state <= DONE;
             done <=1;
         end
         DONE: begin
             if (!start) begin
                 state <= IDLE;
                 done <=0;
             end else begin
                 // Stay in DONE if start is high
             end
      endcase
   end
end

endmodule