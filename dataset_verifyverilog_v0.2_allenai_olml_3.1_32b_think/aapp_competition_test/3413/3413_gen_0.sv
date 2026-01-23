module governor_convergence (
input clk,
input rst_n,
input start,
input [3:0] party_vector,
input [5:0] edge_mask,
output reg [3:0] months,
output reg done
);

reg [3:0] party_vector_reg;
reg [5:0] edge_mask_reg;
reg [2:0] state;
reg [3:0] month_count;
reg [3:0] months_reg;
reg [3:0] current_party;
reg done_reg;

assign done = done_reg;
assign months = months_reg;

always @(posedge clk) begin
  if (!rst_n) begin
    party_vector_reg <= 4'd0;
    edge_mask_reg <= 6'd0;
    state <= 3'd0;
    month_count <= 4'd0;
    months_reg <= 4'd0;
    done_reg <= 1'b0;
  end else begin
    case (state)
      3'd0: // IDLE
        if (start == 1) begin
          party_vector_reg <= party_vector;
          edge_mask_reg <= edge_mask;
          state <= 3'd1; // FIND_COMPONENTS
        end
        else begin
          state <= 3'd0;
        end
      3'd1: // FIND_COMPONENTS
        // Assume component found, move to flip
        state <= 3'd2;
      3'd2: // FLIP_COMPONENT
        current_party <= ~party_vector_reg; // incorrect flip
        // Check convergence.
        if (current_party[0] == current_party[1] && current_party[1] == current_party[2] && current_party[2] == current_party[3]) begin
            month_count <= month_count + 1; // increment after flip?
            done_reg <=1'b1;
            state <=3'd3; // DONE
            months_reg <= month_count;
        end else begin
            month_count <= month_count + 1;
            if (month_count > 4) begin // max 16, but use 4 for example
                done_reg <=1'b1;
                state <=3'd3;
            end else begin
                state <=3'd1; // restart find components
            end
        end
      3'd3: // DONE
        state <=3'd3;
      default: state <=3'd0;
    endcase
  end
endmodule