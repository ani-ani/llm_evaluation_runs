module arcade_expected_value (
  input clk,
  input rst_n,
  input start,
  input [3:0] num_rows,
  input signed [7:0] payouts [0:9],
  input [19:0] probs [0:9][0:4],
  output reg signed [31:0] expected_value,
  output reg done
);

typedef enum logic [1:0] {IDLE, INIT, ITERATE, DONE_STATE} state_t;
state_t state;

reg [6:0] iter;
reg signed [31:0] current_E [0:9];
wire signed [31:0] next_E [0:9];
wire [31:0] abs_delta [0:9];
wire [31:0] max_delta;

function logic [3:0] get_neighbor(input [3:0] h, input [2:0] d, input [3:0] num_rows);
  logic [2:0] row_h;
  logic [3:0] pos_h;
  logic [3:0] row_start[4];
  logic valid;
  logic [3:0] nh;

  row_start[1] = 0;
  row_start[2] = 1;
  row_start[3] = 3;
  row_start[4] = 6;

  if (h == 0) begin row_h = 1; pos_h = 0; end
  else if (h <= 2) begin row_h = 2; pos_h = h - 1; end
  else if (h <= 5) begin row_h = 3; pos_h = h - 3; end
  else begin row_h = 4; pos_h = h - 6; end

  if (row_h > num_rows) begin
    valid = 0;
    nh = 4'b1111;
  end else begin
    case(d)
      0: begin
        if (row_h < num_rows && row_h < 4 && pos_h <= row_h) begin
          nh = row_start[row_h+1] + pos_h;
          valid = (nh < 10) ? 1 : 0;
        end else begin
          valid = 0;
        end
      end
      1: begin
        if (row_h < num_rows && row_h < 4 && (pos_h+1) <= row_h) begin
          nh = row_start[row_h+1] + (pos_h + 1);
          valid = (nh < 10) ? 1 : 0;
        end else begin
          valid = 0;
        end
      end
      2: begin
        if (row_h > 1 && pos_h >= 1) begin
          nh = row_start[row_h-1] + (pos_h - 1);
          valid = (row_h-1 <= num_rows && nh < 10) ? 1 : 0;
        end else begin
          valid = 0;
        end
      end
      3: begin
        if (row_h > 1 && pos_h < row_h-1) begin
          nh = row_start[row_h-1] + pos_h;
          valid = (row_h-1 <= num_rows && nh < 10) ? 1 : 0;
        end else begin
          valid = 0;
        end
      end
      4: begin
        nh = h;
        valid = 1;
      end
      default: begin
        valid = 0;
        nh = 4'b1111;
      end
    endcase
  end

  if (!valid) nh = 4'b1111;
  return nh;
endfunction

generate
  for (genvar h = 0; h < 10; h++) begin : next_E_gen
    wire signed [31:0] scaled_payout = $signed(payouts[h]);
    wire signed [31:0] payout_term = scaled_payout <<< 22;
    reg signed [31:0] sum;
    always_comb begin
      sum = payout_term;
      for (int d = 0; d < 5; d++) begin
        logic [3:0] nh = get_neighbor(h[3:0], d[2:0], num_rows);
        if (nh < 10) begin
          logic signed [19:0] prob = probs[h][d];
          logic signed [51:0] product = $signed(prob) * $signed({current_E[nh][31], current_E[nh]});
          logic signed [31:0] scaled_product = product >>> 10;
          sum = sum + scaled_product;
        end
      end
    end
    assign next_E[h] = sum;
  end
endgenerate

generate
  for (genvar i = 0; i < 10; i++) begin : abs_delta_gen
    assign abs_delta[i] = (current_E[i] >= next_E[i]) ? 
                           (current_E[i] - next_E[i]) : 
                           (next_E[i] - current_E[i]);
  end
endgenerate

logic [31:0] max01, max23, max45, max67, max89, max0123, max4567, max01234567;
assign max01 = (abs_delta[0] > abs_delta[1]) ? abs_delta[0] : abs_delta[1];
assign max23 = (abs_delta[2] > abs_delta[3]) ? abs_delta[2] : abs_delta[3];
assign max0123 = (max01 > max23) ? max01 : max23;
assign max45 = (abs_delta[4] > abs_delta[5]) ? abs_delta[4] : abs_delta[5];
assign max67 = (abs_delta[6] > abs_delta[7]) ? abs_delta[6] : abs_delta[7];
assign max4567 = (max45 > max67) ? max45 : max67;
assign max89 = (abs_delta[8] > abs_delta[9]) ? abs_delta[8] : abs_delta[9];
assign max01234567 = (max0123 > max4567) ? max0123 : max4567;
assign max_delta = (max01234567 > max89) ? max01234567 : max89;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    done <= 0;
    state <= IDLE;
    iter <= 0;
    for (int i=0; i<10; i++) current_E[i] <= 0;
    expected_value <= 0;
  end else begin
    case(state)
      IDLE: begin
        done <= 0;
        if (start) begin
          state <= INIT;
        end
      end

      INIT: begin
        iter <= 0;
        for (int i=0; i<10; i++) current_E[i] <= 0;
        state <= ITERATE;
      end

      ITERATE: begin
        if (iter >= 100 || max_delta < 32'd4096) begin
          expected_value <= current_E[0];
          done <= 1;
          state <= DONE_STATE;
        end else begin
          for (int i=0; i<10; i++) current_E[i] <= next_E[i];
          iter <= iter + 1;
        end
      end

      DONE_STATE: begin
        done <= 1;
        if (start) begin
          done <= 0;
          state <= INIT;
        end
      end
    endcase
  end
end

endmodule