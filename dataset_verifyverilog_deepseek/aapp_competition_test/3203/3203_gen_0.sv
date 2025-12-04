module mission_assigner(input clk, input rst_n, input start, input [6:0] probabilities[0:3][0:3], output reg [31:0] max_prob, output reg done);
  typedef enum logic [1:0] {IDLE, CALCULATING, DONE} state_t;
  state_t state, next_state;
  reg [4:0] perm_counter;
  reg [31:0] scaled_probs[0:3][0:3];
  wire [1:0] p0, p1, p2, p3;
  wire [31:0] prob0, prob1, prob2, prob3;
  wire [63:0] product01, product012, product0123;
  wire [31:0] scaled01, scaled012, current_product;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      max_prob <= 32'd0;
      perm_counter <= 5'd0;
    end else begin
      state <= next_state;
      case (state)
        IDLE: if (start) begin
          perm_counter <= 5'd0;
          max_prob <= 32'd0;
          for (int i=0; i<4; i++) for (int j=0; j<4; j++) scaled_probs[i][j] <= (probabilities[i][j] * 65'd65536 + 7'd50) / 7'd100;
        end
        CALCULATING: perm_counter <= perm_counter + 1;
        DONE: ;
      endcase
      if (state == CALCULATING && perm_counter < 5'd24 && current_product > max_prob)
        max_prob <= current_product;
    end
  end

  always_comb begin
    next_state = state;
    done = 1'b0;
    case (state)
      IDLE: if (start) next_state = CALCULATING;
      CALCULATING: if (perm_counter == 5'd31) next_state = DONE;
      DONE: begin
        done = 1'b1;
        if (!start) next_state = IDLE;
      end
    endcase
  end

  always_comb begin
    case (perm_counter)
      5'd0: {p0,p1,p2,p3} = {2'd0,2'd1,2'd2,2'd3};
      5'd1: {p0,p1,p2,p3} = {2'd0,2'd1,2'd3,2'd2};
      5'd2: {p0,p1,p2,p3} = {2'd0,2'd2,2'd1,2'd3};
      5'd3: {p0,p1,p2,p3} = {2'd0,2'd2,2'd3,2'd1};
      5'd4: {p0,p1,p2,p3} = {2'd0,2'd3,2'd1,2'd2};
      5'd5: {p0,p1,p2,p3} = {2'd0,2'd3,2'd2,2'd1};
      5'd6: {p0,p1,p2,p3} = {2'd1,2'd0,2'd2,2'd3};
      5'd7: {p0,p1,p2,p3} = {2'd1,2'd0,2'd3,2'd2};
      5'd8: {p0,p1,p2,p3} = {2'd1,2'd2,2'd0,2'd3};
      5'd9: {p0,p1,p2,p3} = {2'd1,2'd2,2'd3,2'd0};
      5'd10: {p0,p1,p2,p3} = {2'd1,2'd3,2'd0,2'd2};
      5'd11: {p0,p1,p2,p3} = {2'd1,2'd3,2'd2,2'd0};
      5'd12: {p0,p1,p2,p3} = {2'd2,2'd0,2'd1,2'd3};
      5'd13: {p0,p1,p2,p3} = {2'd2,2'd0,2'd3,2'd1};
      5'd14: {p0,p1,p2,p3} = {2'd2,2'd1,2'd0,2'd3};
      5'd15: {p0,p1,p2,p3} = {2'd2,2'd1,2'd3,2'd0};
      5'd16: {p0,p1,p2,p3} = {2'd2,2'd3,2'd0,2'd1};
      5'd17: {p0,p1,p2,p3} = {2'd2,2'd3,2'd1,2'd0};
      5'd18: {p0,p1,p2,p3} = {2'd3,2'd0,2'd1,2'd2};
      5'd19: {p0,p1,p2,p3} = {2'd3,2'd0,2'd2,2'd1};
      5'd20: {p0,p1,p2,p3} = {2'd3,2'd1,2'd0,2'd2};
      5'd21: {p0,p1,p2,p3} = {2'd3,2'd1,2'd2,2'd0};
      5'd22: {p0,p1,p2,p3} = {2'd3,2'd2,2'd0,2'd1};
      5'd23: {p0,p1,p2,p3} = {2'd3,2'd2,2'd1,2'd0};
      default: {p0,p1,p2,p3} = {2'd0,2'd1,2'd2,2'd3};
    endcase
  end

  assign prob0 = scaled_probs[0][p0];
  assign prob1 = scaled_probs[1][p1];
  assign prob2 = scaled_probs[2][p2];
  assign prob3 = scaled_probs[3][p3];
  assign product01 = prob0 * prob1;
  assign scaled01 = product01[47:16];
  assign product012 = scaled01 * prob2;
  assign scaled012 = product012[47:16];
  assign product0123 = scaled012 * prob3;
  assign current_product = product0123[47:16];
endmodule