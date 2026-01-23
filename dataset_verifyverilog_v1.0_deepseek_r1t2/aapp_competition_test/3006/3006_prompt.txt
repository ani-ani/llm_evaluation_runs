module dna_editing (
  input clk,
  input rst_n,
  input start,
  input [0:0] op1_type [0:1999],
  input [31:0] op1_pos [0:1999],
  input [7:0] op1_char [0:1999],
  input [0:0] op2_type [0:1999],
  input [31:0] op2_pos [0:1999],
  input [7:0] op2_char [0:1999],
  output reg result
);

  reg [7:0] string1 [0:999];
  reg [7:0] string2 [0:999];

  integer i, j, k;
  reg [31:0] pos1, pos2;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      for (i=0; i<1000; i=i+1) begin
        string1[i] <= 0;
        string2[i] <= 0;
      end
    end else if (start) begin
      for (i=0; i<1000; i=i+1) begin
        string1[i] <= 0;
        string2[i] <= 0;
      end

      for (i=0; i<2000; i=i+1) begin
        if (op1_type[i] == 1) begin
          pos1 = op1_pos[i] % 1000;
          if (pos1 < 1000) begin
            for (j=999; j>pos1; j=j-1) begin
              string1[j] <= string1[j-1];
            end
            string1[pos1] <= op1_char[i];
          end
        end else begin
          pos1 = op1_pos[i] % 1000;
          if (pos1 < 1000) begin
            for (j=pos1; j<999; j=j+1) begin
              string1[j] <= string1[j+1];
            end
            string1[999] <= 0;
          end
        end
      end

      for (i=0; i<2000; i=i+1) begin
        if (op2_type[i] == 1) begin
          pos2 = op2_pos[i] % 1000;
          if (pos2 < 1000) begin
            for (j=999; j>pos2; j=j-1) begin
              string2[j] <= string2[j-1];
            end
            string2[pos2] <= op2_char[i];
          end
        end else begin
          pos2 = op2_pos[i] % 1000;
          if (pos2 < 1000) begin
            for (j=pos2; j<999; j=j+1) begin
              string2[j] <= string2[j+1];
            end
            string2[999] <= 0;
          end
        end
      end

      result <= 0;
      for (k=0; k<1000; k=k+1) begin
        if (string1[k] != string2[k]) begin
          result <= 1;
        end
      end
    end
  end
endmodule