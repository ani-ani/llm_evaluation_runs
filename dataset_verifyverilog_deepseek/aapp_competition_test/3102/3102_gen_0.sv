module house_number_counter(
  input clk,
  input rst_n,
  input start,
  input [15:0] L,
  input [15:0] R,
  output reg [15:0] count,
  output reg done
);

  typedef enum logic { IDLE, COUNTING } state_t;
  state_t state;
  reg [15:0] current_number;

  wire [3:0] d4 = (current_number / 16'd10000);
  wire [15:0] rem1 = current_number % 16'd10000;
  wire [3:0] d3 = rem1 / 16'd1000;
  wire [15:0] rem2 = rem1 % 16'd1000;
  wire [3:0] d2 = rem2 / 16'd100;
  wire [15:0] rem3 = rem2 % 16'd100;
  wire [3:0] d1 = rem3 / 16'd10;
  wire [3:0] d0 = rem3 % 16'd10;

  wire has_4 = (d4 == 4'd4) || (d3 == 4'd4) || (d2 == 4'd4) || (d1 == 4'd4) || (d0 == 4'd4);

  logic [2:0] start_idx;
  always_comb begin
    if (d4 != 4'd0) start_idx = 3'd4;
    else if (d3 != 4'd0) start_idx = 3'd3;
    else if (d2 != 4'd0) start_idx = 3'd2;
    else if (d1 != 4'd0) start_idx = 3'd1;
    else if (d0 != 4'd0) start_idx = 3'd0;
    else start_idx = 3'd5;
  end

  wire cover_d4 = (start_idx == 3'd4);
  wire cover_d3 = (start_idx >= 3'd3) & (start_idx <= 3'd4);
  wire cover_d2 = (start_idx >= 3'd2) & (start_idx <= 3'd4);
  wire cover_d1 = (start_idx >= 3'd1) & (start_idx <= 3'd4);
  wire cover_d0 = (start_idx >= 3'd0) & (start_idx <= 3'd4);

  wire [3:0] lucky_cnt = 
    {3'd0, cover_d4 & ((d4 == 4'd6) || (d4 == 4'd8))} +
    {3'd0, cover_d3 & ((d3 == 4'd6) || (d3 == 4'd8))} +
    {3'd0, cover_d2 & ((d2 == 4'd6) || (d2 == 4'd8))} +
    {3'd0, cover_d1 & ((d1 == 4'd6) || (d1 == 4'd8))} +
    {3'd0, cover_d0 & ((d0 == 4'd6) || (d0 == 4'd8))};

  wire [3:0] non_lucky_cnt = 
    {3'd0, cover_d4 & ~((d4 == 4'd6) || (d4 == 4'd8)) & (d4 != 4'd0)} +
    {3'd0, cover_d3 & ~((d3 == 4'd6) || (d3 == 4'd8)) & (d3 != 4'd0)} +
    {3'd0, cover_d2 & ~((d2 == 4'd6) || (d2 == 4'd8)) & (d2 != 4'd0)} +
    {3'd0, cover_d1 & ~((d1 == 4'd6) || (d1 == 4'd8)) & (d1 != 4'd0)} +
    {3'd0, cover_d0 & ~((d0 == 4'd6) || (d0 == 4'd8)) & (d0 != 4'd0)};

  wire valid_num = (lucky_cnt == non_lucky_cnt) & ~has_4;

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= IDLE;
      count <= 16'd0;
      done <= 1'b0;
      current_number <= 16'd0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            current_number <= L;
            count <= 16'd0;
            state <= COUNTING;
          end
        end
        COUNTING: begin
          if (current_number <= R) begin
            if (valid_num) count <= count + 16'd1;
            current_number <= current_number + 16'd1;
          end else begin
            done <= 1'b1;
            state <= IDLE;
          end
        end
      endcase
    end
  end

endmodule