module date_format_converter (input clk, input rst_n, input start, input [7:0] char_in, output reg [7:0] char_out, output reg out_valid, output reg done);
localparam IDLE = 8'd0, READ_Y1 =1, READ_Y2=2, READ_Y3=3, READ_Y4=4, SKIP_DASH1=5, READ_M1=6, READ_M2=7, SKIP_DASH2=8, READ_D1=9, READ_D2=10, OUTPUT_D1=11, OUTPUT_D2=12, OUTPUT_DASH1=13, OUTPUT_M1=14, OUTPUT_M2=15, OUTPUT_DASH2=16, OUTPUT_Y1=17, OUTPUT_Y2=18, OUTPUT_Y3=19, OUTPUT_Y4=20, DONE=21;
reg [4:0] state;
reg [7:0] y1, y2, y3, y4;
reg [7:0] m1, m2;
reg [7:0] d1, d2;

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      y1 <= 8'h00; y2 <= 8'h00; y3 <= 8'h00; y4 <= 8'h00;
      m1 <= 8'h00; m2 <= 8'h00;
      d1 <= 8'h00; d2 <= 8'h00;
      char_out <= 8'h00;
      out_valid <= 0;
      done <= 0;
   end else begin
      case(state)
         IDLE: if (start) state <= READ_Y1; else state <= IDLE; char_out <= 8'h00;
         READ_Y1: y1 <= char_in; state <= READ_Y2;
         READ_Y2: y2 <= char_in; state <= READ_Y3;
         READ_Y3: y3 <= char_in; state <= READ_Y4;
         READ_Y4: y4 <= char_in; state <= SKIP_DASH1;
         SKIP_DASH1: state <= READ_M1;
         READ_M1: m1 <= char_in; state <= READ_M2;
         READ_M2: m2 <= char_in; state <= SKIP_DASH2;
         SKIP_DASH2: state <= READ_D1;
         READ_D1: d1 <= char_in; state <= READ_D2;
         READ_D2: d2 <= char_in; state <= OUTPUT_D1;
         OUTPUT_D1: char_out <= d1; state <= OUTPUT_D2;
         OUTPUT_D2: char_out <= d2; state <= OUTPUT_DASH1;
         OUTPUT_DASH1: char_out <= 8'h2d; state <= OUTPUT_M1;
         OUTPUT_M1: char_out <= m1; state <= OUTPUT_M2;
         OUTPUT_M2: char_out <= m2; state <= OUTPUT_DASH2;
         OUTPUT_DASH2: char_out <= 8'h2d; state <= OUTPUT_Y1;
         OUTPUT_Y1: char_out <= y1; state <= OUTPUT_Y2;
         OUTPUT_Y2: char_out <= y2; state <= OUTPUT_Y3;
         OUTPUT_Y3: char_out <= y3; state <= OUTPUT_Y4;
         OUTPUT_Y4: char_out <= y4; state <= DONE;
         DONE: state <= DONE;
      endcase

      out_valid = (state >= OUTPUT_D1 && state <= OUTPUT_Y4);
      done = (state == DONE);

      if (!out_valid) char_out <= 8'h00;
   end
end
endmodule