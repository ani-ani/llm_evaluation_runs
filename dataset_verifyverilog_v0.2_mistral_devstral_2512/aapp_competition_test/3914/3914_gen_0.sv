module curfew_enforcement #(
  parameter N = 64,
  parameter MAX_D = 32,
  parameter B = 16
)(
  input wire clk,
  input wire rst_n,
  input wire start,
  input wire [7:0] d_in,
  input wire valid_in,
  input wire [31:0] a_in,
  output wire [5:0] addr_out,
  output wire [15:0] result,
  output wire done,
  output wire req_en
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    LOAD,
    COMPUTE,
    DONE
  } state_t;

  // Internal registers
  state_t state;
  logic [5:0] addr_reg;
  logic [31:0] prefix [0:N-1];
  logic [31:0] total_sum;
  logic [5:0] i_reg;
  logic [15:0] max_complaints;
  logic [7:0] d_reg;
  logic [5:0] left_limit;
  logic [5:0] right_limit;
  logic [31:0] left_students;
  logic [31:0] right_students;
  logic [31:0] max_fill;
  logic [15:0] complaints;
  logic [5:0] count;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      addr_reg <= 0;
      total_sum <= 0;
      i_reg <= 0;
      max_complaints <= 0;
      d_reg <= 0;
      count <= 0;
      for (int j = 0; j < N; j = j + 1) begin
        prefix[j] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD;
            addr_reg <= 0;
            total_sum <= 0;
            d_reg <= d_in;
            count <= 0;
            for (int j = 0; j < N; j = j + 1) begin
              prefix[j] <= 0;
            end
          end
        end
        LOAD: begin
          if (valid_in) begin
            prefix[addr_reg] <= a_in;
            if (addr_reg > 0) begin
              prefix[addr_reg] <= prefix[addr_reg - 1] + a_in;
            end
            total_sum <= prefix[addr_reg];
            count <= count + 1;
            if (count == N - 1) begin
              state <= COMPUTE;
              i_reg <= 1;
              max_complaints <= 0;
            end else begin
              addr_reg <= addr_reg + 1;
            end
          end
        end
        COMPUTE: begin
          left_limit <= i_reg * d_reg;
          right_limit <= N - 1 - i_reg * d_reg;
          left_students <= (left_limit < N) ? prefix[left_limit] : prefix[N-1];
          right_students <= (right_limit >= 0) ? (total_sum - prefix[right_limit]) : total_sum;
          max_fill <= (left_students < right_students) ? left_students : right_students;
          complaints <= i_reg - (max_fill / B);
          if (complaints > max_complaints) begin
            max_complaints <= complaints;
          end
          if (i_reg == N/2) begin
            state <= DONE;
            result <= max_complaints;
          end else begin
            i_reg <= i_reg + 1;
          end
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
          end
        end
      endcase
    end
  end

  // Output assignments
  assign addr_out = addr_reg;
  assign done = (state == DONE);
  assign req_en = (state == IDLE) || (state == LOAD && !valid_in);

endmodule