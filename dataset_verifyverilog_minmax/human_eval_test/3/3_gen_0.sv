module balance_checker(
  input clk,
  input rst_n,
  input start,
  input [7:0] ops [0:7],
  input [2:0] op_count,
  output reg below_zero_flag,
  output reg done
);

reg state;
reg signed [11:0] balance_12;
reg [2:0] ops_done;

localparam IDLE = 1'b0;
localparam ACTIVE = 1'b1;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    below_zero_flag <= 1'b0;
    done <= 1'b0;
    balance_12 <= 12'sb0;
    ops_done <= 3'b0;
  end else begin
    case (state)
      IDLE: begin
        if (start) begin
          below_zero_flag <= 1'b0;
          done <= 1'b0;
          balance_12 <= 12'sb0;
          ops_done <= 3'b0;
          if (op_count == 3'b0) begin
            done <= 1'b1;
            state <= IDLE;
          end else begin
            state <= ACTIVE;
          end
        end
      end

      ACTIVE: begin
        balance_12 <= balance_12 + $signed( { {4{ops[ops_done][7]}}, ops[ops_done] } );
        if (balance_12 < 0) begin
          below_zero_flag <= 1'b1;
        end
        ops_done <= ops_done + 1;
        if (ops_done == op_count - 1) begin
          done <= 1'b1;
          state <= IDLE;
        end else begin
          state <= ACTIVE;
        end
      end

      default: state <= IDLE;
    endcase
  end
end

endmodule