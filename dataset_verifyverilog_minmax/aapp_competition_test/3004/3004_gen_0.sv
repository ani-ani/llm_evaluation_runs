module fence_painter (
  input clk,
  input rst_n,
  input start,
  input [3:0] num_offers,
  input [7:0][15:0] offer_data,
  output reg [3:0] min_count,
  output reg impossible,
  output reg done
);

  // State machine
  typedef enum logic {S_IDLE = 1'b0, S_WORK = 1'b1} state_t;
  state_t state;

  // Registers
  reg [7:0] current_mask;
  reg [15:0] coverage;
  reg [2:0] color_count;
  reg [7:0] color_present;

  // Constants
  localparamparam FULL_COVERAGE = 16'hFFFF;
  localparamparam MAX_COMB = 256;

  // Compute coverage and color count for a given mask (combinational)
  function [15:0] get_coverage;
    input [7:0] mask;
    input [3:0] n_offers;
    input [7:0][15:0] offers;
    reg [15:0] cov;
    reg [7:0] colors;
    integer i;
    reg [3:0] s;
    reg [3:0] e;
    integer j;
  begin
    cov = 16'h0000;
    colors = 8'h00;
    for (i = 0; i < 8; i = i + 1) begin
      if (mask[i] && (i < n_offers)) begin
        s = offers[i][11:8];
        e = offers[i][15:12];
        if (e >= s) begin
          for (j = s; j <= e; j = j + 1) begin
            cov[j] = 1'b1;
          end
        end
        colors[offers[i][2:0]] = 1'b1;
      end
    end
    get_coverage = cov;
  end
  endfunction

  function [2:0] get_color_count;
    input [7:0] mask;
    input [3:0] n_offers;
    input [7:0][15:0] offers;
    reg [7:0] colors;
    integer i;
  begin
    colors = 8'h00;
    for (i = 0; i < 8; i = i + 1) begin
      if (mask[i] && (i < n_offers)) begin
        colors[offers[i][2:0]] = 1'b1;
      end
    end
    get_color_count = (colors[0] + colors[1] + colors[2] + colors[3] + colors[4] + colors[5] + colors[6] + colors[7]);
  endfunction

  // Combinational evaluation of current combination validity
  wire [15:0] eval_coverage;
  wire [2:0] eval_color_count;
  wire [3:0] eval_offer_count;
  wire eval_valid;
  assign eval_coverage = get_coverage(current_mask, num_offers, offer_data);
  assign eval_color_count = get_color_count(current_mask, num_offers, offer_data);
  assign eval_offer_count = (current_mask[0] + current_mask[1] + current_mask[2] + current_mask[3] +
                             current_mask[4] + current_mask[5] + current_mask[6] + current_mask[7]);
  assign eval_valid = (eval_coverage == FULL_COVERAGE) && (eval_color_count <= 3);

  // Sequential state machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      current_mask <= 8'h00;
      min_count <= 4'd0;
      impossible <= 1'b1;
      done <= 1'b0;
      coverage <= 16'h0000;
      color_count <= 3'd0;
      color_present <= 8'h00;
    end else begin
      case (state)
        S_IDLE: begin
          done <= 1'b0;
          impossible <= 1'b1;
          if (start) begin
            // Initialize for enumeration
            current_mask <= 8'h00;
            min_count <= 4'd8; // upper bound: 8 offers max
            state <= S_WORK;
          end
        end

        S_WORK: begin
          // Evaluate current combination
          if (eval_valid) begin
            if (eval_offer_count < min_count) begin
              min_count <= eval_offer_count;
              impossible <= 1'b0;
            end
          end

          // Proceed to next combination or finish
          if (current_mask == 8'hFF) begin
            state <= S_IDLE;
            done <= 1'b1;
            coverage <= eval_coverage;
            color_count <= eval_color_count;
            color_present <= 8'h00; // not required as output, kept for completeness
          end else begin
            current_mask <= current_mask + 1;
          end
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule