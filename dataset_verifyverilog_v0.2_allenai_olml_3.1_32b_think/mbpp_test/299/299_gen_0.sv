module max_aggregate (
   input clk,
   input rst_n,
   input start,
   input [2:0] num_entries,
   input [63:0] name_in,
   input [7:0] marks_in,
   input valid_in,
   output reg [63:0] result_name,
   output reg [9:0] result_total,
   output reg done,
   output reg error
);

localparam IDLE = 3'd0;
localparam ACCUMULATE = 3'd1;
localparam FIND_MAX = 3'd2;
localparam DONE = 3'd3;

reg [2:0] state;
reg [3:0] entry_count;
reg [63:0] name_reg [7:0];
reg [9:0] marks_reg [7:0];
reg [63:0] result_name;
reg [9:0] result_total;
reg done;
reg error;

wire [63:0] max_name;
wire [9:0] max_val;

always @(*) begin
   max_name = 64'b0;
   max_val = 10'd0;
   if (name_reg[0] !=0) begin
      max_name = name_reg[0];
      max_val = marks_reg[0];
   end
   if (name_reg[1] !=0 && marks_reg[1] > max_val) begin
      max_name = name_reg[1];
      max_val = marks_reg[1];
   end
   if (name_reg[2] !=0 && marks_reg[2] > max_val) begin
      max_name = name_reg[2];
      max_val = marks_reg[2];
   end
   if (name_reg[3] !=0 && marks_reg[3] > max_val) begin
      max_name = name_reg[3];
      max_val = marks_reg[3];
   end
   if (name_reg[4] !=0 && marks_reg[4] > max_val) begin
      max_name = name_reg[4];
      max_val = marks_reg[4];
   end
   if (name_reg[5] !=0 && marks_reg[5] > max_val) begin
      max_name = name_reg[5];
      max_val = marks_reg[5];
   end
   if (name_reg[6] !=0 && marks_reg[6] > max_val) begin
      max_name = name_reg[6];
      max_val = marks_reg[6];
   end
   if (name_reg[7] !=0 && marks_reg[7] > max_val) begin
      max_name = name_reg[7];
      max_val = marks_reg[7];
   end
end

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      entry_count <=0;
      name_reg <= 64'b0;
      marks_reg <= 10'b0;
      result_name <= 64'b0;
      result_total <= 10'b0;
      done <=0;
      error <=0;
   end else begin
      if (state == IDLE) begin
          if (start) begin
              if (num_entries ==0) begin
                  error <=1;
                  done <=1;
                  state <= DONE;
              end else begin
                  state <= ACCUMULATE;
                  entry_count <=0;
                  name_reg <= 64'b0;
                  marks_reg <= 10'b0;
              end
          end
      end else if (state == ACCUMULATE) begin
          if (valid_in) begin
              if ( (name_reg[0] !=0) && (name_reg[0] == name_in) ) begin
                  marks_reg[0] <= marks_reg[0] + marks_in;
              end else if ( (name_reg[1] !=0) && (name_reg[1] == name_in) ) begin
                  marks_reg[1] <= marks_reg[1] + marks_in;
              end else if ( (name_reg[2] !=0) && (name_reg[2] == name_in) ) begin
                  marks_reg[2] <= marks_reg[2] + marks_in;
              end else if ( (name_reg[3] !=0) && (name_reg[3] == name_in) ) begin
                  marks_reg[3] <= marks_reg[3] + marks_in;
              end else if ( (name_reg[4] !=0) && (name_reg[4] == name_in) ) begin
                  marks_reg[4] <= marks_reg[4] + marks_in;
              end else if ( (name_reg[5] !=0) && (name_reg[5] == name_in) ) begin
                  marks_reg[5] <= marks_reg[5] + marks_in;
              end else if ( (name_reg[6] !=0) && (name_reg[6] == name_in) ) begin
                  marks_reg[6] <= marks_reg[6] + marks_in;
              end else if ( (name_reg[7] !=0) && (name_reg[7] == name_in) ) begin
                  marks_reg[7] <= marks_reg[7] + marks_in;
              end else begin
                  if (name_reg[0] ==0) begin
                      name_reg[0] <= name_in;
                      marks_reg[0] <= marks_in;
                  end else if (name_reg[1] ==0) begin
                      name_reg[1] <= name_in;
                      marks_reg[1] <= marks_in;
                  end else if (name_reg[2] ==0) begin
                      name_reg[2] <= name_in;
                      marks_reg[2] <= marks_in;
                  end else if (name_reg[3] ==0) begin
                      name_reg[3] <= name_in;
                      marks_reg[3] <= marks_in;
                  end else if (name_reg[4] ==0) begin
                      name_reg[4] <= name_in;
                      marks_reg[4] <= marks_in;
                  end else if (name_reg[5] ==0) begin
                      name_reg[5] <= name_in;
                      marks_reg[5] <= marks_in;
                  end else if (name_reg[6] ==0) begin
                      name_reg[6] <= name_in;
                      marks_reg[6] <= marks_in;
                  end else if (name_reg[7] ==0) begin
                      name_reg[7] <= name_in;
                      marks_reg[7] <= marks_in;
                  end else begin
                  end
              end
              entry_count <= entry_count +1;
              if (entry_count == num_entries) begin
                  state <= FIND_MAX;
              end
          end
      end else if (state == FIND_MAX) begin
          result_name <= max_name;
          result_total <= max_val;
          state <= DONE;
      end else if (state == DONE) begin
      end
   end
end

assign done = done;
assign error = error;
assign result_name = result_name;
assign result_total = result_total;

endmodule