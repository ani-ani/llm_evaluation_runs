module widget_packing(
  input clk,
  input rst_n,
  input start,
  input [31:0] N,
  output reg [31:0] empty_squares,
  output reg done
);

  reg [5:0] counter;
  reg busy;
  reg [31:0] N_reg;
  reg [15:0] low, high;
  wire [15:0] mid = (low + high) >> 1;
  reg [15:0] H0;
  reg [31:0] min_empty_reg;

  wire [15:0] candidate_H [3:0];
  wire [31:0] candidate_W [3:0];
  wire [31:0] candidate_empty [3:0];

  assign candidate_H[0] = (H0 >= 16'd2) ? H0 - 16'd2 : 16'd1;
  assign candidate_H[1] = (H0 >= 16'd1) ? H0 - 16'd1 : 16'd1;
  assign candidate_H[2] = H0;
  assign candidate_H[3] = H0 + 16'd1;

  generate
    genvar i;
    for (i=0; i<4; i=i+1) begin : compute_candidates
      wire [31:0] W_raw = (N_reg + candidate_H[i] - 1) / ((candidate_H[i] != 0) ? candidate_H[i] : 1);
      wire [15:0] min_W = (candidate_H[i] + 1) >> 1;
      wire [31:0] max_W = 2 * candidate_H[i];
      wire [31:0] clamped_W = (W_raw < min_W) ? min_W : (W_raw > max_W) ? max_W : W_raw;
      assign candidate_empty[i] = clamped_W * candidate_H[i] - N_reg;
    end
  endgenerate

  wire [31:0] min_empty_wire;
  assign min_empty_wire = (candidate_empty[0] <= candidate_empty[1] && 
                          candidate_empty[0] <= candidate_empty[2] && 
                          candidate_empty[0] <= candidate_empty[3]) ? candidate_empty[0] :
                         (candidate_empty[1] <= candidate_empty[2] && 
                          candidate_empty[1] <= candidate_empty[3]) ? candidate_empty[1] :
                         (candidate_empty[2] <= candidate_empty[3]) ? candidate_empty[2] : candidate_empty[3];

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      counter <= 0;
      busy <= 0;
      done <= 0;
      empty_squares <= 0;
      N_reg <= 0;
      low <= 0;
      high <= 0;
      H0 <= 0;
      min_empty_reg <= 0;
    end else begin
      done <= 0;
      if (busy) begin
        counter <= counter + 1;
        case (counter)
          0: begin
            N_reg <= N;
            low <= 0;
            high <= 16'd65535;
          end
          1, 2, 3, 4, 5: begin
            if (mid * mid <= (N_reg >> 1))
              low <= mid;
            else
              high <= mid - 1;
          end
          6: min_empty_reg <= min_empty_wire;
          31: begin
            empty_squares <= min_empty_reg;
            done <= 1;
            busy <= 0;
          end
          default: ;
        endcase
      end else if (start) begin
        busy <= 1;
        counter <= 0;
      end
    end
  end

endmodule