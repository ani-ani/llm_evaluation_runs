module road_assignment (
   input clk,
   input rst_n,
   input start,
   input [3:0] city_a [0:7],
   input [3:0] city_b [0:7],
   output reg [3:0] out_city,
   output reg [3:0] out_road_end,
   output reg out_valid,
   output reg out_done
);

reg [7:0] assigned_roads;
reg [3:0] current_city;
reg [2:0] road_index;
reg [1:0] state;

reg [3:0] out_city_reg;
reg [3:0] out_road_end_reg;
reg out_valid_reg;
reg out_done_reg;

assign out_city = out_city_reg;
assign out_road_end = out_road_end_reg;
assign out_valid = out_valid_reg;
assign out_done = out_done_reg;

localparam IDLE = 2'd0;
localparam SEARCH = 2'd1;
localparam DONE = 2'd2;

always @(posedge clk) begin
   if (!rst_n) begin
      assigned_roads <= 8'b0;
      current_city <= 4'd1;
      road_index <= 3'd0;
      state <= IDLE;
      out_city_reg <= 4'd0;
      out_road_end_reg <= 4'd0;
      out_valid_reg <= 1'b0;
      out_done_reg <= 1'b0;
   end else begin
      out_city_reg <= 4'd0;
      out_road_end_reg <= 4'd0;
      out_valid_reg <= 1'b0;
      out_done_reg <= 1'b0;

      case (state)
         IDLE: begin
            if (start) begin
               state <= SEARCH;
               assigned_roads <= 8'b0;
               current_city <= 4'd1;
               road_index <= 3'd0;
            end else begin
               state <= IDLE;
            end
         end
         SEARCH: begin
            if (road_index < 8) begin
               if (!assigned_roads[road_index] && (city_a[road_index] == current_city || city_b[road_index] == current_city)) begin
                  assigned_roads[road_index] <= 1'b1;
                  out_city_reg <= current_city;
                  out_road_end_reg <= (city_a[road_index] == current_city) ? city_b[road_index] : city_a[road_index];
                  out_valid_reg <= 1'b1;
                  current_city <= current_city + 1;
                  road_index <= 3'd0;
                  if (current_city > 8) begin
                     state <= DONE;
                  end else begin
                     state <= SEARCH;
                  end
               end else begin
                  road_index <= road_index + 1;
               end
            end else begin
               current_city <= current_city + 1;
               road_index <= 3'd0;
               if (current_city > 8) begin
                  state <= DONE;
               end else begin
                  state <= SEARCH;
               end
            end
         end
         DONE: begin
            state <= DONE;
            out_done_reg <= 1'b1;
         end
      endcase
   end
end
endmodule