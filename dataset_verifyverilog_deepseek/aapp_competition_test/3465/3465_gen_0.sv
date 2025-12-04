module road_assignment(
  input clk,
  input rst_n,
  input start,
  input [2:0] num_cities,
  input [7:0][5:0] roads,
  output reg [7:0][5:0] assignments,
  output reg done
);

  reg processing;
  reg [2:0] current_city;
  reg [7:0] used_roads;
  reg [7:0][5:0] assignments_reg;
  reg done_reg;
  reg start_d;

  wire [7:0] select;
  wire [2:0] selected_idx;
  wire selected_valid;
  wire [5:0] new_road;
  wire current_city_done = (current_city == num_cities);
  wire start_pulse = start && !start_d;

  generate
    genvar i;
    for (i=0; i<8; i=i+1) begin : gen_select
      assign select[i] = !used_roads[i] && (
        (roads[i][5:3] == current_city) ||
        (roads[i][2:0] == current_city)
      );
    end
  endgenerate

  always_comb begin
    selected_idx = 3'd0;
    selected_valid = 1'b0;
    for (int j=0; j<8; j=j+1) begin
      if (select[j]) begin
        selected_idx = j[2:0];
        selected_valid = 1'b1;
        break;
      end
    end
  end

  assign new_road = (roads[selected_idx][5:3] == current_city) ? 
    roads[selected_idx] : 
    {roads[selected_idx][2:0], roads[selected_idx][5:3]};

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      processing <= 1'b0;
      current_city <= 3'd0;
      used_roads <= 8'd0;
      assignments_reg <= 48'd0;
      done_reg <= 1'b0;
      start_d <= 1'b0;
    end else begin
      start_d <= start;
      if (processing) begin
        if (!current_city_done) begin
          if (selected_valid) begin
            assignments_reg[current_city] <= new_road;
            used_roads[selected_idx] <= 1'b1;
            current_city <= current_city + 1;
          end else begin
            assignments_reg[current_city] <= 6'd0;
            current_city <= current_city + 1;
          end
        end else begin
          done_reg <= 1'b1;
          processing <= 1'b0;
        end
      end else if (start_pulse) begin
        processing <= 1'b1;
        current_city <= 3'd0;
        used_roads <= 8'd0;
        assignments_reg <= 48'd0;
        done_reg <= 1'b0;
      end
    end
  end

  always @(*) begin
    assignments = assignments_reg;
    done = done_reg;
  end

endmodule