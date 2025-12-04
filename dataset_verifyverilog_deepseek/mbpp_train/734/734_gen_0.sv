module sum_subarray_prod (
  input clk,
  input rst_n,
  input start,
  input [3:0] element [7:0],
  input [2:0] arr_len,
  output reg [31:0] result,
  output reg done
);

typedef enum logic [1:0] {IDLE, COMPUTE, DONE} state_t;
state_t state;

reg [3:0] iter_count;
reg [31:0] ans, res;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    ans <= 32'b0;
    res <= 32'b0;
    iter_count <= 4'b0;
    result <= 32'b0;
    done <= 1'b0;
  end else begin
    case (state)
      IDLE: begin
        done <= 1'b0;
        if (start) begin
          iter_count <= {1'b0, arr_len};
          ans <= 32'b0;
          res <= 32'b0;
          state <= COMPUTE;
        end
      end
      COMPUTE: begin
        automatic logic [3:0] current_elem = element[iter_count - 4'd1];
        automatic logic [31:0] incr = current_elem * (1 + res);
        ans <= ans + incr;
        res <= incr;
        iter_count <= iter_count - 1;
        if (iter_count == 4'd1) begin
          state <= DONE;
        end
      end
      DONE: begin
        result <= ans;
        done <= 1'b1;
        state <= IDLE;
      end
    endcase
  end
end

endmodule