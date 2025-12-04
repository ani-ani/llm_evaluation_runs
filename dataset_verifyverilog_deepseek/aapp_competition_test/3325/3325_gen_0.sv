module water_height_calculator(
  input clk,
  input rst_n,
  input start,
  input [3:0] N_vertices,
  input [15:0] D_depth,
  input [15:0] L_liters,
  input [11:0] vertices [0:7][0:1],
  output reg [15:0] height,
  output reg done
);

  reg signed [31:0] vertices_reg[0:7][0:1]; // Q16.16 format
  reg [3:0] N_vertices_reg;
  reg [31:0] D_depth_reg;
  reg [31:0] L_liters_reg;
  reg [31:0] minY;
  reg [31:0] maxY;
  reg [3:0] iter;
  reg [31:0] low;
  reg [31:0] high;
  reg [31:0] mid;
  reg [63:0] volume;
  
  // Mid calculation wire to use in comb logic
  wire [31:0] mid_wire = (low + high) >>> 1; // Q16.16 average
  
  // Submerged area calculation for current mid
  wire [31:0] submerged_area;
  compute_submerged_area area_calc (
    .h(mid_wire),
    .vertices(vertices_reg),
    .n_vertices(N_vertices_reg),
    .area(submerged_area)
  );
  
  // Volume calculation
  assign volume = submerged_area * D_depth_reg;
  
  // Bookkeeping for vertex conversion and preprocessing
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      height <= 0;
      iter <= 0;
      low <= 0;
      high <= 0;
      N_vertices_reg <= 0;
      D_depth_reg <= 0;
      L_liters_reg <= 0;
      for (i=0; i<8; i++) begin
        vertices_reg[i][0] <= 0;
        vertices_reg[i][1] <= 0;
      end
      minY <= 0;
      maxY <= 0;
    end else begin
      done <= 0;
      
      if (start) begin
        // Convert all vertices to Q16.16 format
        N_vertices_reg <= N_vertices;
        D_depth_reg <= {D_depth, 16\'b0}; // Convert D_depth to Q16.16 (bits [31:16] = integer)
        L_liters_reg <= {L_liters, 16\'b0}; // Same for L_liters
        
        for (i=0; i<N_vertices; i++) begin
          vertices_reg[i][0] <= {{20{vertices[i][0][11]}}, vertices[i][0]};
          vertices_reg[i][1] <= {{20{vertices[i][1][11]}}, vertices[i][1]};
        end
        
        // Calculate minY and maxY
        minY <= vertices_reg[0][1];
        maxY <= vertices_reg[0][1];
        for (i=1; i<N_vertices; i++) begin
          if (vertices_reg[i][1] < minY) minY <= vertices_reg[i][1];
          if (vertices_reg[i][1] > maxY) maxY <= vertices_reg[i][1];
        end
        
        low <= minY;
        high <= maxY;
        iter <= 0;
        
      end else if (iter < 16) begin
        iter <= iter + 1;
        
        // Update based on comparison
        if (volume > (L_liters_reg << 16)) begin
          high <= mid_wire;
        end else begin
          low <= mid_wire;
        end
        
        // In final iteration, output height
        if (iter == 15) begin
          height <= mid_wire[31:16]; // Truncate fractional bits to 2 decimals
          done <= 1;
        end
      end
    end
  end
  
  // Submodule for calculating submerged area
  module compute_submerged_area(
    input [31:0] h,
    input signed [31:0] vertices [0:7][0:1],
    input [3:0] n_vertices,
    output reg [31:0] area
  );
    
    integer i;
    reg signed [63:0] area_temp;
    always @(*) begin
      area_temp = 0;
      
      for (i=0; i<n_vertices; i++) begin
        integer j = (i == n_vertices-1) ? 0 : i+1;
        reg signed [31:0] x1, y1, x2, y2;
        x1 = vertices[i][0];
        y1 = vertices[i][1];
        x2 = vertices[j][0];
        y2 = vertices[j][1];
        
        if (y1 <= h && y2 <= h) begin
          // Full trapezoid contribution
          area_temp += ((x1 + x2) * (y2 - y1)) >>> 1;
        end else if ((y1 <= h) && (y2 > h)) begin
          // Compute intersection and partial contribution
          reg signed [31:0] dy = y2 - y1;
          if (dy != 0) begin
            reg signed [31:0] t = ((h - y1) * (32\'h10000)) / dy; // Q16.16 (h-y1)/dy
            reg signed [31:0] x_int = x1 + ((x2 - x1) * t) >>> 16;
            area_temp += ((x1 + x_int) * (h - y1)) >>> 1;
          end
        end else if ((y2 <= h) && (y1 > h)) begin
          // Compute intersection and partial contribution
          reg signed [31:0] dy = y1 - y2;
          if (dy != 0) begin
            reg signed [31:0] t = ((h - y2) * (32\'h10000)) / dy; // Q16.16 (h-y2)/dy
            reg signed [31:0] x_int = x2 + ((x1 - x2) * t) >>> 16;
            area_temp += ((x2 + x_int) * (h - y2)) >>> 1;
          end
        end
      end
      
      area = area_temp[47:16]; // Convert Q32.32 to Q16.16
    end
    
  endmodule
  
endmodule