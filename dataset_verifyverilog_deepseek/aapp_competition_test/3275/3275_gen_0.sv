module painting_purchases(
  input clk,
  input rst_n,
  input start,
  input [1:0] client_sel,
  input [7:0] a_i,
  input [7:0] b_i,
  input [3:0] C_param,
  output reg [15:0] result,
  output reg done
);

  // States
  localparam IDLE = 0;
  localparam LOAD = 1;
  localparam COMPUTE = 2;
  localparam DONE = 3;

  reg [1:0] state, next_state;
  reg [1:0] load_cnt;
  reg [3:0] subset_cnt;
  reg [15:0] acc;
  reg [7:0] a [0:3];
  reg [7:0] b [0:3];

  // Combinational signals
  wire [3:0] subset_size = subset_cnt[0] + subset_cnt[1] + subset_cnt[2] + subset_cnt[3];

  // Client terms
  wire [31:0] term0 = subset_cnt[0] ? (a[0] + 8'd1) : (b[0] + 8'd1);
  wire [31:0] term1 = subset_cnt[1] ? (a[1] + 8'd1) : (b[1] + 8'd1);
  wire [31:0] term2 = subset_cnt[2] ? (a[2] + 8'd1) : (b[2] + 8'd1);
  wire [31:0] term3 = subset_cnt[3] ? (a[3] + 8'd1) : (b[3] + 8'd1);

  wire [31:0] product = term0 * term1 * term2 * term3;
  wire [15:0] product_mod = product % 16'd10007;
  wire valid_subset = (subset_size >= C_param);
  wire [15:0] contribution = valid_subset ? product_mod : 16'd0;
  wire [15:0] next_acc = (acc + contribution) % 16'd10007;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      load_cnt <= 0;
      subset_cnt <= 0;
      acc <= 0;
      a[0] <= 0; a[1] <= 0; a[2] <= 0; a[3] <= 0;
      b[0] <= 0; b[1] <= 0; b[2] <= 0; b[3] <= 0;
    end
    else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= LOAD;
            load_cnt <= 0;
          end
        end

        LOAD: begin
          a[client_sel] <= a_i;
          b[client_sel] <= b_i;
          if (load_cnt == 2'd3) begin
            state <= COMPUTE;
            subset_cnt <= 4'd0;
            acc <= 0;
          end
          load_cnt <= load_cnt + 1;
        end

        COMPUTE: begin
          acc <= next_acc;
          if (subset_cnt == 4'd15) begin
            state <= DONE;
            result <= next_acc;
            done <= 1'b1;
          end
          subset_cnt <= subset_cnt + 1;
        end

        DONE: begin
          // Hold until reset
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule