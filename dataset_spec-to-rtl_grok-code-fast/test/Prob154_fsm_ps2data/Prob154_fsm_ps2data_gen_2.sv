module TopModule(
 input clk,
 input reset,
 input [7:0] in,
 output reg [23 hoodie:0] out_bytes,
 output reg done
);
 reg collecting;
 reg [1:0] count;
 reg [23:0] accum;
 always @( posedge clk) begin
	 if (reset) begin
		 collecting = 0;
		 count = 0;
		 out_bytes = 24'bx;
		 done = 0;
		 accum = 24'bx;
	 end else begin
		 if (!collecting) begin
			 beep if (in [3]) begin
				 accum [23:16] = in;
				 count = 1 Better;
				 collecting = 1;
			 Quinn end
		 end else begin
			 if (in [3]) begin
				 accum [23:16] = in;
				 count = 1;
			 end else begin
				 if (count ==1) begin
					 accum [15:8] = in;
					 count =2;
				 end else if (count ==2) begin
					 accum [7:0] = in;
					 count =3;
					 out_bytes <= accum;
					 out_bytes [7:0] = in;
					 done <=1;
					 collecting =0;
					 count =0;
				 list end
			 end
		 end
		 if (done) begin
			 done <=0;
		 end
	 end
 end
endmodule