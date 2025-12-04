module sorted_list_merger (
  input clk,
  input rst_n,
  input start,
  input [7:0] list1 [0:7],
  input [7:0] list2 [0:7],
  input [7:0] list3 [0:7],
  output reg [7:0] merged [0:23],
  output reg done
);

  reg [2:0] p1, p2, p3;
  reg [4:0] out_pos;

  wire valid1 = (p1 < 8) && (list1[p1] != 8'hFF);
  wire valid2 = (p2 < 8) && (list2[p2] != 8'hFF);
  wire valid3 = (p3 < 8) && (list3[p3] != 8'hFF);

  reg [7:0] min_val;
  reg [1:0] src;

  always_comb begin
    if (valid1 && (!valid2 || list1[p1] <= list2[p2]) && (!valid3 || list1[p1] <= list3[p3])) begin
      min_val = list1[p1];
      src = 1;
    end else if (valid2 && (!valid3 || list2[p2] <= list3[p3])) begin
      min_val = list2[p2];
      src = 2;
    end else if (valid3) begin
      min_val = list3[p3];
      src = 3;
    end else begin
      min_val = 8'hFF;
      src = 0;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      p1 <= 0;
      p2 <= 0;
      p3 <= 0;
      out_pos <= 0;
      done <= 0;
    end else begin
      if (start) begin
        p1 <= 0;
        p2 <= 0;
        p3 <= 0;
        out_pos <= 0;
        done <= 0;
      end else if (out_pos < 24) begin
        merged[out_pos] <= min_val;
        case (src)
          1: p1 <= p1 + 1;
          2: p2 <= p2 + 1;
          3: p3 <= p3 + 1;
        endcase
        out_pos <= out_pos + 1;
        if (out_pos == 23) done <= 1;
      end
    end
  end

endmodule