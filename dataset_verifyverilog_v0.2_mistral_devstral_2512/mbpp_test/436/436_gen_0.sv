module neg_nos (
  input [3:0][7:0] list_in,
  output [3:0][7:0] result,
  output [1:0] count
);

  reg [1:0] neg_count = 0;
  reg [3:0][7:0] temp_result = '0;

  always @* begin
    neg_count = 0;
    temp_result = '0;

    if (list_in[0][7]) begin
      temp_result[neg_count] = list_in[0];
      neg_count = neg_count + 1;
    end

    if (list_in[1][7]) begin
      temp_result[neg_count] = list_in[1];
      neg_count = neg_count + 1;
    end

    if (list_in[2][7]) begin
      temp_result[neg_count] = list_in[2];
      neg_count = neg_count + 1;
    end

    if (list_in[3][7]) begin
      temp_result[neg_count] = list_in[3];
      neg_count = neg_count + 1;
    end

    result = temp_result;
    count = neg_count;
  end

endmodule