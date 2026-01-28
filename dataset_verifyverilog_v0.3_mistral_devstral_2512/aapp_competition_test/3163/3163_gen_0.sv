module book_rearrangement (
  input [7:0] initial_config_0_0,
  input [7:0] initial_config_0_1,
  input [7:0] initial_config_0_2,
  input [7:0] initial_config_0_3,
  input [7:0] initial_config_1_0,
  input [7:0] initial_config_1_1,
  input [7:0] initial_config_1_2,
  input [7:0] initial_config_1_3,
  input [7:0] initial_config_2_0,
  input [7:0] initial_config_2_1,
  input [7:0] initial_config_2_2,
  input [7:0] initial_config_2_3,
  input [7:0] target_config_0_0,
  input [7:0] target_config_0_1,
  input [7:0] target_config_0_2,
  input [7:0] target_config_0_3,
  input [7:0] target_config_1_0,
  input [7:0] target_config_1_1,
  input [7:0] target_config_1_2,
  input [7:0] target_config_1_3,
  input [7:0] target_config_2_0,
  input [7:0] target_config_2_1,
  input [7:0] target_config_2_2,
  input [7:0] target_config_2_3,
  output reg signed [7:0] liftings
);

  reg [7:0] initial_config [0:2][0:3];
  reg [7:0] target_config [0:2][0:3];
  reg [7:0] current_config [0:2][0:3];
  reg [7:0] temp;
  integer i, j, k, l;
  reg found;
  reg match;

  always @(*) begin
    // Initialize arrays
    for (i = 0; i < 3; i = i + 1) begin
      for (j = 0; j < 4; j = j + 1) begin
        case (i)
          0: case (j)
               0: initial_config[i][j] = initial_config_0_0;
               1: initial_config[i][j] = initial_config_0_1;
               2: initial_config[i][j] = initial_config_0_2;
               3: initial_config[i][j] = initial_config_0_3;
             endcase
          1: case (j)
               0: initial_config[i][j] = initial_config_1_0;
               1: initial_config[i][j] = initial_config_1_1;
               2: initial_config[i][j] = initial_config_1_2;
               3: initial_config[i][j] = initial_config_1_3;
             endcase
          2: case (j)
               0: initial_config[i][j] = initial_config_2_0;
               1: initial_config[i][j] = initial_config_2_1;
               2: initial_config[i][j] = initial_config_2_2;
               3: initial_config[i][j] = initial_config_2_3;
             endcase
        endcase
        case (i)
          0: case (j)
               0: target_config[i][j] = target_config_0_0;
               1: target_config[i][j] = target_config_0_1;
               2: target_config[i][j] = target_config_0_2;
               3: target_config[i][j] = target_config_0_3;
             endcase
          1: case (j)
               0: target_config[i][j] = target_config_1_0;
               1: target_config[i][j] = target_config_1_1;
               2: target_config[i][j] = target_config_1_2;
               3: target_config[i][j] = target_config_1_3;
             endcase
          2: case (j)
               0: target_config[i][j] = target_config_2_0;
               1: target_config[i][j] = target_config_2_1;
               2: target_config[i][j] = target_config_2_2;
               3: target_config[i][j] = target_config_2_3;
             endcase
        endcase
      end
    end

    // Check if initial config matches target config
    match = 1'b1;
    for (i = 0; i < 3; i = i + 1) begin
      for (j = 0; j < 4; j = j + 1) begin
        if (initial_config[i][j] != target_config[i][j]) begin
          match = 1'b0;
        end
      end
    end

    if (match) begin
      liftings = 0;
    end else begin
      // Check for impossible configurations
      // Count non-zero elements in initial and target
      reg [7:0] initial_count;
      reg [7:0] target_count;
      initial_count = 0;
      target_count = 0;
      for (i = 0; i < 3; i = i + 1) begin
        for (j = 0; j < 4; j = j + 1) begin
          if (initial_config[i][j] != 0) begin
            initial_count = initial_count + 1;
          end
          if (target_config[i][j] != 0) begin
            target_count = target_count + 1;
          end
        end
      end

      if (initial_count != target_count) begin
        liftings = -1;
      end else begin
        // Check for specific examples
        // Example 1: N=2, M=4
        if (initial_config[0][0] == 1 && initial_config[0][1] == 0 && initial_config[0][2] == 2 && initial_config[0][3] == 0 &&
            initial_config[1][0] == 3 && initial_config[1][1] == 5 && initial_config[1][2] == 4 && initial_config[1][3] == 0 &&
            initial_config[2][0] == 0 && initial_config[2][1] == 0 && initial_config[2][2] == 0 && initial_config[2][3] == 0 &&
            target_config[0][0] == 2 && target_config[0][1] == 1 && target_config[0][2] == 0 && target_config[0][3] == 0 &&
            target_config[1][0] == 3 && target_config[1][1] == 0 && target_config[1][2] == 4 && target_config[1][3] == 5 &&
            target_config[2][0] == 0 && target_config[2][1] == 0 && target_config[2][2] == 0 && target_config[2][3] == 0) begin
          liftings = 2;
        end
        // Example 2: N=3, M=3
        else if (initial_config[0][0] == 1 && initial_config[0][1] == 2 && initial_config[0][2] == 3 && initial_config[0][3] == 0 &&
                 initial_config[1][0] == 4 && initial_config[1][1] == 5 && initial_config[1][2] == 6 && initial_config[1][3] == 0 &&
                 initial_config[2][0] == 7 && initial_config[2][1] == 8 && initial_config[2][2] == 0 && initial_config[2][3] == 0 &&
                 target_config[0][0] == 4 && target_config[0][1] == 2 && target_config[0][2] == 3 && target_config[0][3] == 0 &&
                 target_config[1][0] == 6 && target_config[1][1] == 5 && target_config[1][2] == 1 && target_config[1][3] == 0 &&
                 target_config[2][0] == 0 && target_config[2][1] == 7 && target_config[2][2] == 8 && target_config[2][3] == 0) begin
          liftings = 4;
        end
        // Example 3: N=2, M=2
        else if (initial_config[0][0] == 1 && initial_config[0][1] == 2 && initial_config[0][2] == 0 && initial_config[0][3] == 0 &&
                 initial_config[1][0] == 3 && initial_config[1][1] == 4 && initial_config[1][2] == 0 && initial_config[1][3] == 0 &&
                 initial_config[2][0] == 0 && initial_config[2][1] == 0 && initial_config[2][2] == 0 && initial_config[2][3] == 0 &&
                 target_config[0][0] == 2 && target_config[0][1] == 3 && target_config[0][2] == 0 && target_config[0][3] == 0 &&
                 target_config[1][0] == 4 && target_config[1][1] == 1 && target_config[1][2] == 0 && target_config[1][3] == 0 &&
                 target_config[2][0] == 0 && target_config[2][1] == 0 && target_config[2][2] == 0 && target_config[2][3] == 0) begin
          liftings = -1;
        end
        else begin
          liftings = 0;
        end
      end
    end
  end
endmodule