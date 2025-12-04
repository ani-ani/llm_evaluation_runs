module factorial_or_sum_list(
  input        clk,
  input        rst_n,
  input        start,
  input  [3:0] n,
  output reg [7:0][15:0] result_array,
  output reg       done
);

typedef enum logic [2:0] {
  IDLE,
  INIT,
  COMPUTE_EVEN,
  COMPUTE_ODD,
  STORE,
  DONE
} state_t;

reg [2:0] current_state, next_state;
reg [3:0] i;
reg [3:0] j;
reg [15:0] product;
reg [15:0] temp_result;

always_ff @(posedge clk or negedge rst_n) begin
  if (~rst_n) begin
    current_state <= IDLE;
    done <= 0;
    result_array <= '{default:0};
    i <= 4'd0;
    j <= 4'd0;
    product <= 16'd0;
    temp_result <= 16'd0;
  end else begin
    case (current_state)
      IDLE: begin
        done <= 0;
        if (start) current_state <= INIT;
      end

      INIT: begin
        i <= 4'd1;
        done <= 0;
        if (i[0] == 1'b1) current_state <= COMPUTE_ODD;
        else begin
          j <= 4'd2;
          product <= 16'd1;
          current_state <= COMPUTE_EVEN;
        end
      end

      COMPUTE_ODD: begin
        temp_result <= (i * (i + 1)) >> 1;  // sum = i*(i+1)/2
        current_state <= STORE;
      end

      COMPUTE_EVEN: begin
        if (j <= i) begin
          product <= product * j;
          j <= j + 1;
        end else begin
          temp_result <= product;
          current_state <= STORE;
        end
      end

      STORE: begin
        result_array[i-1] <= temp_result;
        if (i < n) begin
          i <= i + 1;
          if ((i+1)[0]) current_state <= COMPUTE_ODD;
          else begin
            j <= 4'd2;
            product <= 16'd1;
            current_state <= COMPUTE_EVEN;
          end
        end else
          current_state <= DONE;
      end

      DONE: begin
        done <= 1'b1;
        if (start) current_state <= INIT;
      end

      default: current_state <= IDLE;
    endcase
  end
end

endmodule