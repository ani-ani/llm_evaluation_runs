module wiring_possibilities(
  input clk,
  input rst_n,
  input start,
  input [1:0] m,
  input [3:0] photo1_sw,
  input [3:0] photo1_lgt,
  input [3:0] photo2_sw,
  input [3:0] photo2_lgt,
  output reg [19:0] result,
  output reg done
);

  typedef enum {IDLE, PROCESS, DONE} state_t;
  state_t state, next_state;

  reg [4:0] perm_index;
  reg [4:0] valid_count;
  reg [1:0] p [0:3];
  reg [1:0] m_reg;
  reg [3:0] photo1_sw_reg, photo1_lgt_reg, photo2_sw_reg, photo2_lgt_reg;

  wire [3:0] permuted_sw_photo1;
  wire [3:0] permuted_sw_photo2;
  wire photo1_valid;
  wire photo2_valid;
  wire all_valid;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      perm_index <= 5'd0;
      valid_count <= 5'd0;
      result <= 20'd0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            perm_index <= 5'd0;
            valid_count <= 5'd0;
            m_reg <= m;
            photo1_sw_reg <= photo1_sw;
            photo1_lgt_reg <= photo1_lgt;
            photo2_sw_reg <= photo2_sw;
            photo2_lgt_reg <= photo2_lgt;
          end
        end
        PROCESS: begin
          if (all_valid) begin
            valid_count <= valid_count + 1;
          end
          perm_index <= perm_index + 1;
        end
        DONE: begin
          result <= valid_count % 20'd1000003;
          done <= 1'b1;
        end
      endcase
    end
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE: if (start) next_state = PROCESS;
      PROCESS: if (perm_index == 5'd23) next_state = DONE;
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  always_comb begin
    case (perm_index)
      5'd0: {p[0],p[1],p[2],p[3]} = {2'd0,2'd1,2'd2,2'd3};
      5'd1: {p[0],p[1],p[2],p[3]} = {2'd0,2'd1,2'd3,2'd2};
      5'd2: {p[0],p[1],p[2],p[3]} = {2'd0,2'd2,2'd1,2'd3};
      5'd3: {p[0],p[1],p[2],p[3]} = {2'd0,2'd2,2'd3,2'd1};
      5'd4: {p[0],p[1],p[2],p[3]} = {2'd0,2'd3,2'd1,2'd2};
      5'd5: {p[0],p[1],p[2],p[3]} = {2'd0,2'd3,2'd2,2'd1};
      5'd6: {p[0],p[1],p[2],p[3]} = {2'd1,2'd0,2'd2,2'd3};
      5'd7: {p[0],p[1],p[2],p[3]} = {2'd1,2'd0,2'd3,2'd2};
      5'd8: {p[0],p[1],p[2],p[3]} = {2'd1,2'd2,2'd0,2'd3};
      5'd9: {p[0],p[1],p[2],p[3]} = {2'd1,2'd2,2'd3,2'd0};
      5'd10: {p[0],p[1],p[2],p[3]} = {2'd1,2'd3,2'd0,2'd2};
      5'd11: {p[0],p[1],p[2],p[3]} = {2'd1,2'd3,2'd2,2'd0};
      5'd12: {p[0],p[1],p[2],p[3]} = {2'd2,2'd0,2'd1,2'd3};
      5'd13: {p[0],p[1],p[2],p[3]} = {2'd2,2'd0,2'd3,2'd1};
      5'd14: {p[0],p[1],p[2],p[3]} = {2'd2,2'd1,2'd0,2'd3};
      5'd15: {p[0],p[1],p[2],p[3]} = {2'd2,2'd1,2'd3,2'd0};
      5'd16: {p[0],p[1],p[2],p[3]} = {2'd2,2'd3,2'd0,2'd1};
      5'd17: {p[0],p[1],p[2],p[3]} = {2'd2,2'd3,2'd1,2'd0};
      5'd18: {p[0],p[1],p[2],p[3]} = {2'd3,2'd0,2'd1,2'd2};
      5'd19: {p[0],p[1],p[2],p[3]} = {2'd3,2'd0,2'd2,2'd1};
      5'd20: {p[0],p[1],p[2],p[3]} = {2'd3,2'd1,2'd0,2'd2};
      5'd21: {p[0],p[1],p[2],p[3]} = {2'd3,2'd1,2'd2,2'd0};
      5'd22: {p[0],p[1],p[2],p[3]} = {2'd3,2'd2,2'd0,2'd1};
      5'd23: {p[0],p[1],p[2],p[3]} = {2'd3,2'd2,2'd1,2'd0};
      default: {p[0],p[1],p[2],p[3]} = {8{1'b0}};
    endcase
  end

  assign permuted_sw_photo1[0] = photo1_sw_reg[p[0]];
  assign permuted_sw_photo1[1] = photo1_sw_reg[p[1]];
  assign permuted_sw_photo1[2] = photo1_sw_reg[p[2]];
  assign permuted_sw_photo1[3] = photo1_sw_reg[p[3]];

  assign permuted_sw_photo2[0] = photo2_sw_reg[p[0]];
  assign permuted_sw_photo2[1] = photo2_sw_reg[p[1]];
  assign permuted_sw_photo2[2] = photo2_sw_reg[p[2]];
  assign permuted_sw_photo2[3] = photo2_sw_reg[p[3]];

  assign photo1_valid = (m_reg < 1) ? 1'b1 : (permuted_sw_photo1 == photo1_lgt_reg);
  assign photo2_valid = (m_reg < 2) ? 1'b1 : (permuted_sw_photo2 == photo2_lgt_reg);
  assign all_valid = photo1_valid && photo2_valid;

endmodule