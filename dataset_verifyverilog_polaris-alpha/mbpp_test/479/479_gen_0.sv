module first_digit(
  input  wire        clk,
  input  wire        rst_n,
  input  wire        start,
  input  wire [15:0] num,
  output reg  [3:0]  result,
  output reg         done
);

  reg [15:0] work;
  reg [2:0]  div_cnt;
  reg        busy;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result  <= 4'd0;
      done    <= 1'b0;
      work    <= 16'd0;
      div_cnt <= 3'd0;
      busy    <= 1'b0;
    end else begin
      // Default
      done <= 1'b0;

      if (!busy) begin
        if (start) begin
          // Initialize operation
          work    <= num;
          div_cnt <= 3'd0;
          busy    <= 1'b1;
        end
      end else begin
        // Busy: perform one division per cycle if needed
        if (work < 10 || div_cnt == 3'd4) begin
          // Completed: work holds first digit
          result <= work[3:0];
          done   <= 1'b1;
          busy   <= 1'b0;
        end else begin
          // Divide by 10
          work    <= work / 10;
          div_cnt <= div_cnt + 3'd1;
        end
      end
    end
  end

endmodule