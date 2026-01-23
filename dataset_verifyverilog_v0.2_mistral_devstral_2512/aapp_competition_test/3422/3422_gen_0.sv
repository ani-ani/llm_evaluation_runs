module treasure_map_solver (
  input [7:0] p1_data,
  input [7:0] p2_data,
  input [7:0] p3_data,
  input [7:0] p4_data,
  input [1:0] config,
  output [31:0] map_out,
  output valid
);

  reg [1:0] map [0:3][0:3];
  reg [1:0] piece [0:3][0:1];
  integer i, j, tx, ty, zero_count, dist, expected;

  // Assign pieces based on config
  always @(*) begin
    case (config)
      2'b00: begin
        piece[0] = p1_data;
        piece[1] = p2_data;
        piece[2] = p3_data;
        piece[3] = p4_data;
      end
      2'b01: begin
        piece[0] = p1_data;
        piece[1] = p3_data;
        piece[2] = p2_data;
        piece[3] = p4_data;
      end
      2'b10: begin
        piece[0] = p2_data;
        piece[1] = p1_data;
        piece[2] = p3_data;
        piece[3] = p4_data;
      end
      2'b11: begin
        piece[0] = p2_data;
        piece[1] = p4_data;
        piece[2] = p1_data;
        piece[3] = p3_data;
      end
    endcase

    // Assemble 4x4 map
    // Top-left piece (0,0)
    map[0][0] = piece[0][1:0];
    map[0][1] = piece[0][3:2];
    map[1][0] = piece[0][5:4];
    map[1][1] = piece[0][7:6];

    // Top-right piece (0,2)
    map[0][2] = piece[1][1:0];
    map[0][3] = piece[1][3:2];
    map[1][2] = piece[1][5:4];
    map[1][3] = piece[1][7:6];

    // Bottom-left piece (2,0)
    map[2][0] = piece[2][1:0];
    map[2][1] = piece[2][3:2];
    map[3][0] = piece[2][5:4];
    map[3][1] = piece[2][7:6];

    // Bottom-right piece (2,2)
    map[2][2] = piece[3][1:0];
    map[2][3] = piece[3][3:2];
    map[3][2] = piece[3][5:4];
    map[3][3] = piece[3][7:6];

    // Flatten map to output
    for (i = 0; i < 4; i = i + 1) begin
      for (j = 0; j < 4; j = j + 1) begin
        map_out[(i*8) + (j*2) + 1: (i*8) + (j*2)] = map[i][j];
      end
    end

    // Validation logic
    zero_count = 0;
    tx = 0;
    ty = 0;
    valid = 1'b0;

    // Find treasure (0) position
    for (i = 0; i < 4; i = i + 1) begin
      for (j = 0; j < 4; j = j + 1) begin
        if (map[i][j] == 2'b00) begin
          zero_count = zero_count + 1;
          tx = i;
          ty = j;
        end
      end
    end

    // Check for exactly one treasure
    if (zero_count != 1) begin
      valid = 1'b0;
    end else begin
      valid = 1'b1;
      // Check all cells match distance
      for (i = 0; i < 4; i = i + 1) begin
        for (j = 0; j < 4; j = j + 1) begin
          if (map[i][j] != 2'b00) begin
            dist = (i > tx) ? (i - tx) : (tx - i);
            dist = dist + ((j > ty) ? (j - ty) : (ty - j));
            expected = dist % 4;
            if (map[i][j] != expected) begin
              valid = 1'b0;
            end
          end
        end
      end
    end
  end

endmodule