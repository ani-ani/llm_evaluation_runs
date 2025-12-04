module planet_collision_sim(
  input clk,
  input rst_n,
  input start,
  input [3:0][8:0] masses_in,
  input [3:0][2:0] x_in, y_in, z_in,
  input [3:0][3:0] vx_in, vy_in, vz_in,
  output reg [1:0] planet_count,
  output reg [3:0][8:0] masses_out,
  output reg [3:0][2:0] x_out, y_out, z_out,
  output reg [3:0][3:0] vx_out, vy_out, vz_out,
  output reg done
);

parameter MAX_CYCLES = 8;
reg [2:0] cycle;
reg [3:0][8:0] masses_reg;
reg [3:0][2:0] x_reg, y_reg, z_reg;
reg [3:0][3:0] vx_reg, vy_reg, vz_reg;
reg [3:0] active;
reg simulating, sorting;

wire [3:0] any_collision;
wire [3:0][8:0] tmp_masses = masses_reg;
wire [3:0][2:0] tmp_x = x_reg, tmp_y = y_reg, tmp_z = z_reg;
wire [3:0][3:0] tmp_vx = vx_reg, tmp_vy = vy_reg, tmp_vz = vz_reg;
wire [3:0][2:0] calc_x [3:0];
wire [3:0][2:0] calc_y [3:0];
wire [3:0][2:0] calc_z [3:0];

integer i, j;

// Position calculation
generate
for (genvar g=0; g<4; g=g+1) begin : pos_calc
  assign calc_x[g] = (x_reg[g] + $signed(vx_reg[g])) % 8;
  assign calc_y[g] = (y_reg[g] + $signed(vy_reg[g])) % 8;
  assign calc_z[g] = (z_reg[g] + $signed(vz_reg[g])) % 8;
end
endgenerate 

// Collision detection
assign any_collision[0] = active[0] && (
  (active[1] && (calc_x[0] == calc_x[1]) && (calc_y[0] == calc_y[1]) && (calc_z[0] == calc_z[1])) ||
  (active[2] && (calc_x[0] == calc_x[2]) && (calc_y[0] == calc_y[2]) && (calc_z[0] == calc_z[2])) ||
  (active[3] && (calc_x[0] == calc_x[3]) && (calc_y[0] == calc_y[3]) && (calc_z[0] == calc_z[3])));
assign any_collision[1] = active[1] && (
  (active[2] && (calc_x[1] == calc_x[2]) && (calc_y[1] == calc_y[2]) && (calc_z[1] == calc_z[2])) ||
  (active[3] && (calc_x[1] == calc_x[3]) && (calc_y[1] == calc_y[3]) && (calc_z[1] == calc_z[3])));
assign any_collision[2] = active[2] && active[3] && 
  (calc_x[2] == calc_x[3]) && (calc_y[2] == calc_y[3]) && (calc_z[2] == calc_z[3]);
assign any_collision[3] = 1'b0;

// FSM
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    simulating <= 0;
    sorting <= 0;
    done <= 0;
    cycle <= 0;
    active <= 4'b0;
    masses_reg <= 0;
    x_reg <= 0;
    y_reg <= 0;
    z_reg <= 0;
    vx_reg <= 0;
    vy_reg <= 0;
    vz_reg <= 0;
    masses_out <= 0;
    x_out <= 0;
    y_out <= 0;
    z_out <= 0;
    vx_out <= 0;
    vy_out <= 0;
    vz_out <= 0;
    planet_count <= 0;
  end
  else if (sorting) begin
    // Sorting by mass (desc) then coordinates (asc)
    // Pipelined sort - actual implementation requires state for each compare step
    // Placeholder: bubble sort-like approach (full implementation requires more states)
    masses_out <= masses_reg;
    x_out <= x_reg;
    y_out <= y_reg;
    z_out <= z_reg;
    vx_out <= vx_reg;
    vy_out <= vy_reg;
    vz_out <= vz_reg;
    done <= 1;
    sorting <= 0;
  end
  else if (simulating) begin
    done <= 0;
    // Update registers after collision handling
    masses_reg <= tmp_masses;
    x_reg <= tmp_x;
    y_reg <= tmp_y;
    z_reg <= tmp_z;
    vx_reg <= tmp_vx;
    vy_reg <= tmp_vy;
    vz_reg <= tmp_vz;
    active <= ~any_collision & active; // Clear collided planets

    if (cycle == MAX_CYCLES-1 || !any_collision) begin
      simulating <= 0;
      sorting <= 1;
    end
    else begin
      cycle <= cycle + 1;
    end
  end
  else if (start) begin
    // Load initial values
    masses_reg <= masses_in;
    x_reg <= x_in;
    y_reg <= y_in;
    z_reg <= z_in;
    vx_reg <= vx_in;
    vy_reg <= vy_in;
    vz_reg <= vz_in;
    active <= 4'b1111;
    cycle <= 0;
    simulating <= 1;
    sorting <= 0;
    done <= 0;
  end
end

// Collision handling (combinational)
always @(*) begin
  for (i=0; i<4; i=i+1) begin
    if (any_collision[i]) begin
      integer cnt = 1;
      integer m_sum = masses_reg[i];
      integer vx_sum = $signed(vx_reg[i]);
      integer vy_sum = $signed(vy_reg[i]);
      integer vz_sum = $signed(vz_reg[i]);

      for (j=i+1; j<4; j=j+1) begin
        if (active[j] && (calc_x[i] == calc_x[j]) && (calc_y[i] == calc_y[j]) && (calc_z[i] == calc_z[j])) begin
          cnt = cnt + 1;
          m_sum = m_sum + masses_reg[j];
          vx_sum = vx_sum + $signed(vx_reg[j]);
          vy_sum = vy_sum + $signed(vy_reg[j]);
          vz_sum = vz_sum + $signed(vz_reg[j]);
        end
      end

      tmp_masses[i] = m_sum;
      tmp_vx[i] = vx_sum / cnt;
      tmp_vy[i] = vy_sum / cnt;
      tmp_vz[i] = vz_sum / cnt;
    end
  end
end

endmodule