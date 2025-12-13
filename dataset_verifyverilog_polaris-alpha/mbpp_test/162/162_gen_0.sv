module series_sum(
  input        clk,
  input        rst_n,
  input        start,
  input  [4:0] n_in,
  output reg [7:0] sum,
  output reg       done
);

  reg [4:0] work;
  reg       busy;

  // Asynchronous active-low reset, sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum  <= 8'd0;
      done <= 1'b0;
      work <= 5'd0;
      busy <= 1'b0;
    end else begin
      if (start && !busy) begin
        // Initialize computation
        sum  <= {3'b000, n_in};
        work <= (n_in >= 5'd2) ? (n_in - 5'd2) : 5'd0;
        done <= 1'b0;
        busy <= 1'b1;
      end else if (busy) begin
        if (work > 5'd0) begin
          sum <= sum + {3'b000, work};
          if (work > 5'd2)
            work <= work - 5'd2;
          else
            work <= 5'd0;
        end else begin
          done <= 1'b1;
          busy <= 1'b0;
        end
      end else begin
        // Idle state; hold outputs
        done <= done;
        sum  <= sum;
      end
    end
  end

endmodule