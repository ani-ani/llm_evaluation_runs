module pickle_packing (
  input [31:0] s_ridge,
  input [31:0] r_ridge,
  input [6:0] n_available,
  input [6:0] z_percent,
  output reg [3:0] max_pickles
);

  wire [31:0] r_squared = $signed({r_ridge[31:16], r_ridge[15:0]} * {r_ridge[31:16], r_ridge[15:0]}) >> 16;
  wire [31:0] s_squared = $signed({s_ridge[31:16], s_ridge[15:0]} * {s_ridge[31:16], s_ridge[15:0]}) >> 16;
  wire [31:0] area_limit = $signed({s_squared[31:16], s_squared[15:0]} * {z_percent, 16'd0}) >> 16;

  reg [3:0] valid_k = 4'd0;
  integer k;

  always @* begin
    max_pickles = 4'd0;
    for (k = 0; k <= 7; k = k + 1) begin
      if (k > n_available) begin
        valid_k = 4'd0;
      end else begin
        // Area condition: k * r² ≤ area_limit
        wire [31:0] area_check = $signed({r_squared[31:16], r_squared[15:0]} * {k, 16'd0}) >> 16;
        if (area_check > area_limit) begin
          valid_k = 4'd0;
        end else begin
          // Packing condition
          case (k)
            0: valid_k = 4'd1;
            1: valid_k = 4'd1;
            2: valid_k = (2 * r_ridge <= s_ridge) ? 4'd1 : 4'd0;
            3: begin
              wire [31:0] req_radius = $signed({r_ridge[31:16], r_ridge[15:0]} * {16'd21547, 16'd0}) >> 16;
              valid_k = (req_radius <= s_ridge) ? 4'd1 : 4'd0;
            end
            4: begin
              wire [31:0] req_radius = $signed({r_ridge[31:16], r_ridge[15:0]} * {16'd24142, 16'd0}) >> 16;
              valid_k = (req_radius <= s_ridge) ? 4'd1 : 4'd0;
            end
            5: begin
              wire [31:0] req_radius = $signed({r_ridge[31:16], r_ridge[15:0]} * {16'd27010, 16'd0}) >> 16;
              valid_k = (req_radius <= s_ridge) ? 4'd1 : 4'd0;
            end
            6: valid_k = (3 * r_ridge <= s_ridge) ? 4'd1 : 4'd0;
            7: valid_k = (3 * r_ridge <= s_ridge) ? 4'd1 : 4'd0;
          endcase
        end
      end
      if (valid_k) begin
        max_pickles = k;
      end
    end
  end

endmodule