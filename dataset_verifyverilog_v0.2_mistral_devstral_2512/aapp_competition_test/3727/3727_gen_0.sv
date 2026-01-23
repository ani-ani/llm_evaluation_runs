module beautiful_sequence (
  input [3:0] count_0,
  input [3:0] count_1,
  input [3:0] count_2,
  input [3:0] count_3,
  output reg valid,
  output reg [7:0] length,
  output reg [3:0] seq_out_0,
  output reg [3:0] seq_out_1,
  output reg [3:0] seq_out_2,
  output reg [3:0] seq_out_3,
  output reg [3:0] seq_out_4,
  output reg [3:0] seq_out_5,
  output reg [3:0] seq_out_6,
  output reg [3:0] seq_out_7,
  output reg [3:0] seq_out_8,
  output reg [3:0] seq_out_9,
  output reg [3:0] seq_out_10,
  output reg [3:0] seq_out_11,
  output reg [3:0] seq_out_12,
  output reg [3:0] seq_out_13,
  output reg [3:0] seq_out_14,
  output reg [3:0] seq_out_15
);

  reg [3:0] seq [0:15];
  reg [3:0] current_counts [0:3];
  integer i, j;
  reg [3:0] current, next;
  reg [3:0] temp_counts [0:3];
  reg found;

  always @(*) begin
    valid = 1'b0;
    length = 8'd0;
    for (i = 0; i < 16; i = i + 1) begin
      seq[i] = 4'd0;
    end

    // Initialize current counts
    current_counts[0] = count_0;
    current_counts[1] = count_1;
    current_counts[2] = count_2;
    current_counts[3] = count_3;

    // Check for single number sequences
    if (current_counts[0] == 1 && current_counts[1] == 0 && current_counts[2] == 0 && current_counts[3] == 0) begin
      valid = 1'b1;
      length = 8'd1;
      seq[0] = 4'd0;
    end else if (current_counts[0] == 0 && current_counts[1] == 1 && current_counts[2] == 0 && current_counts[3] == 0) begin
      valid = 1'b1;
      length = 8'd1;
      seq[0] = 4'd1;
    end else if (current_counts[0] == 0 && current_counts[1] == 0 && current_counts[2] == 1 && current_counts[3] == 0) begin
      valid = 1'b1;
      length = 8'd1;
      seq[0] = 4'd2;
    end else if (current_counts[0] == 0 && current_counts[1] == 0 && current_counts[2] == 0 && current_counts[3] == 1) begin
      valid = 1'b1;
      length = 8'd1;
      seq[0] = 4'd3;
    end

    // Check for two number sequences
    if (!valid) begin
      // Check 0-1 sequence
      if (current_counts[0] > 0 && current_counts[1] > 0 && current_counts[2] == 0 && current_counts[3] == 0) begin
        if (current_counts[0] == current_counts[1] || current_counts[0] == current_counts[1] + 1 || current_counts[1] == current_counts[0] + 1) begin
          valid = 1'b1;
          length = 8'd0;
          if (current_counts[0] >= current_counts[1]) begin
            for (i = 0; i < current_counts[1]; i = i + 1) begin
              seq[2*i] = 4'd0;
              seq[2*i + 1] = 4'd1;
            end
            if (current_counts[0] > current_counts[1]) begin
              seq[2*current_counts[1]] = 4'd0;
            end
            length = 8'd(current_counts[0] + current_counts[1]);
          end else begin
            for (i = 0; i < current_counts[0]; i = i + 1) begin
              seq[2*i] = 4'd1;
              seq[2*i + 1] = 4'd0;
            end
            if (current_counts[1] > current_counts[0]) begin
              seq[2*current_counts[0]] = 4'd1;
            end
            length = 8'd(current_counts[0] + current_counts[1]);
          end
        end
      end

      // Check 1-2 sequence
      if (!valid && current_counts[1] > 0 && current_counts[2] > 0 && current_counts[0] == 0 && current_counts[3] == 0) begin
        if (current_counts[1] == current_counts[2] || current_counts[1] == current_counts[2] + 1 || current_counts[2] == current_counts[1] + 1) begin
          valid = 1'b1;
          length = 8'd0;
          if (current_counts[1] >= current_counts[2]) begin
            for (i = 0; i < current_counts[2]; i = i + 1) begin
              seq[2*i] = 4'd1;
              seq[2*i + 1] = 4'd2;
            end
            if (current_counts[1] > current_counts[2]) begin
              seq[2*current_counts[2]] = 4'd1;
            end
            length = 8'd(current_counts[1] + current_counts[2]);
          end else begin
            for (i = 0; i < current_counts[1]; i = i + 1) begin
              seq[2*i] = 4'd2;
              seq[2*i + 1] = 4'd1;
            end
            if (current_counts[2] > current_counts[1]) begin
              seq[2*current_counts[1]] = 4'd2;
            end
            length = 8'd(current_counts[1] + current_counts[2]);
          end
        end
      end

      // Check 2-3 sequence
      if (!valid && current_counts[2] > 0 && current_counts[3] > 0 && current_counts[0] == 0 && current_counts[1] == 0) begin
        if (current_counts[2] == current_counts[3] || current_counts[2] == current_counts[3] + 1 || current_counts[3] == current_counts[2] + 1) begin
          valid = 1'b1;
          length = 8'd0;
          if (current_counts[2] >= current_counts[3]) begin
            for (i = 0; i < current_counts[3]; i = i + 1) begin
              seq[2*i] = 4'd2;
              seq[2*i + 1] = 4'd3;
            end
            if (current_counts[2] > current_counts[3]) begin
              seq[2*current_counts[3]] = 4'd2;
            end
            length = 8'd(current_counts[2] + current_counts[3]);
          end else begin
            for (i = 0; i < current_counts[2]; i = i + 1) begin
              seq[2*i] = 4'd3;
              seq[2*i + 1] = 4'd2;
            end
            if (current_counts[3] > current_counts[2]) begin
              seq[2*current_counts[2]] = 4'd3;
            end
            length = 8'd(current_counts[2] + current_counts[3]);
          end
        end
      end
    end

    // Check for three number sequences
    if (!valid) begin
      // Check 0-1-2 sequence
      if (current_counts[0] > 0 && current_counts[1] > 0 && current_counts[2] > 0 && current_counts[3] == 0) begin
        if (current_counts[1] >= current_counts[0] + current_counts[2] - 1 && current_counts[1] <= current_counts[0] + current_counts[2] + 1) begin
          valid = 1'b1;
          length = 8'd0;
          // Start with 0
          if (current_counts[0] >= current_counts[2]) begin
            for (i = 0; i < current_counts[2]; i = i + 1) begin
              seq[3*i] = 4'd0;
              seq[3*i + 1] = 4'd1;
              seq[3*i + 2] = 4'd2;
            end
            for (i = 0; i < current_counts[0] - current_counts[2]; i = i + 1) begin
              seq[3*current_counts[2] + 2*i] = 4'd0;
              seq[3*current_counts[2] + 2*i + 1] = 4'd1;
            end
            if (current_counts[1] > current_counts[0] + current_counts[2] - 1) begin
              seq[3*current_counts[2] + 2*(current_counts[0] - current_counts[2])] = 4'd1;
            end
            length = 8'd(current_counts[0] + current_counts[1] + current_counts[2]);
          end else begin
            for (i = 0; i < current_counts[0]; i = i + 1) begin
              seq[3*i] = 4'd2;
              seq[3*i + 1] = 4'd1;
              seq[3*i + 2] = 4'd0;
            end
            for (i = 0; i < current_counts[2] - current_counts[0]; i = i + 1) begin
              seq[3*current_counts[0] + 2*i] = 4'd2;
              seq[3*current_counts[0] + 2*i + 1] = 4'd1;
            end
            if (current_counts[1] > current_counts[0] + current_counts[2] - 1) begin
              seq[3*current_counts[0] + 2*(current_counts[2] - current_counts[0])] = 4'd1;
            end
            length = 8'd(current_counts[0] + current_counts[1] + current_counts[2]);
          end
        end
      end

      // Check 1-2-3 sequence
      if (!valid && current_counts[1] > 0 && current_counts[2] > 0 && current_counts[3] > 0 && current_counts[0] == 0) begin
        if (current_counts[2] >= current_counts[1] + current_counts[3] - 1 && current_counts[2] <= current_counts[1] + current_counts[3] + 1) begin
          valid = 1'b1;
          length = 8'd0;
          // Start with 1
          if (current_counts[1] >= current_counts[3]) begin
            for (i = 0; i < current_counts[3]; i = i + 1) begin
              seq[3*i] = 4'd1;
              seq[3*i + 1] = 4'd2;
              seq[3*i + 2] = 4'd3;
            end
            for (i = 0; i < current_counts[1] - current_counts[3]; i = i + 1) begin
              seq[3*current_counts[3] + 2*i] = 4'd1;
              seq[3*current_counts[3] + 2*i + 1] = 4'd2;
            end
            if (current_counts[2] > current_counts[1] + current_counts[3] - 1) begin
              seq[3*current_counts[3] + 2*(current_counts[1] - current_counts[3])] = 4'd2;
            end
            length = 8'd(current_counts[1] + current_counts[2] + current_counts[3]);
          end else begin
            for (i = 0; i < current_counts[1]; i = i + 1) begin
              seq[3*i] = 4'd3;
              seq[3*i + 1] = 4'd2;
              seq[3*i + 2] = 4'd1;
            end
            for (i = 0; i < current_counts[3] - current_counts[1]; i = i + 1) begin
              seq[3*current_counts[1] + 2*i] = 4'd3;
              seq[3*current_counts[1] + 2*i + 1] = 4'd2;
            end
            if (current_counts[2] > current_counts[1] + current_counts[3] - 1) begin
              seq[3*current_counts[1] + 2*(current_counts[3] - current_counts[1])] = 4'd2;
            end
            length = 8'd(current_counts[1] + current_counts[2] + current_counts[3]);
          end
        end
      end
    end

    // Check for four number sequences
    if (!valid) begin
      if (current_counts[0] > 0 && current_counts[1] > 0 && current_counts[2] > 0 && current_counts[3] > 0) begin
        if (current_counts[1] + current_counts[2] >= current_counts[0] + current_counts[3] - 1 && current_counts[1] + current_counts[2] <= current_counts[0] + current_counts[3] + 1) begin
          valid = 1'b1;
          length = 8'd0;
          // Start with 0
          if (current_counts[0] >= current_counts[3]) begin
            for (i = 0; i < current_counts[3]; i = i + 1) begin
              seq[4*i] = 4'd0;
              seq[4*i + 1] = 4'd1;
              seq[4*i + 2] = 4'd2;
              seq[4*i + 3] = 4'd3;
            end
            for (i = 0; i < current_counts[0] - current_counts[3]; i = i + 1) begin
              seq[4*current_counts[3] + 2*i] = 4'd0;
              seq[4*current_counts[3] + 2*i + 1] = 4'd1;
            end
            for (i = 0; i < current_counts[1] - current_counts[0] - current_counts[3] + 1; i = i + 1) begin
              seq[4*current_counts[3] + 2*(current_counts[0] - current_counts[3]) + i] = 4'd1;
            end
            for (i = 0; i < current_counts[2] - current_counts[1] - current_counts[3] + 1; i = i + 1) begin
              seq[4*current_counts[3] + 2*(current_counts[0] - current_counts[3]) + (current_counts[1] - current_counts[0] - current_counts[3] + 1) + i] = 4'd2;
            end
            length = 8'd(current_counts[0] + current_counts[1] + current_counts[2] + current_counts[3]);
          end else begin
            for (i = 0; i < current_counts[0]; i = i + 1) begin
              seq[4*i] = 4'd3;
              seq[4*i + 1] = 4'd2;
              seq[4*i + 2] = 4'd1;
              seq[4*i + 3] = 4'd0;
            end
            for (i = 0; i < current_counts[3] - current_counts[0]; i = i + 1) begin
              seq[4*current_counts[0] + 2*i] = 4'd3;
              seq[4*current_counts[0] + 2*i + 1] = 4'd2;
            end
            for (i = 0; i < current_counts[2] - current_counts[3] - current_counts[0] + 1; i = i + 1) begin
              seq[4*current_counts[0] + 2*(current_counts[3] - current_counts[0]) + i] = 4'd2;
            end
            for (i = 0; i < current_counts[1] - current_counts[2] - current_counts[0] + 1; i = i + 1) begin
              seq[4*current_counts[0] + 2*(current_counts[3] - current_counts[0]) + (current_counts[2] - current_counts[3] - current_counts[0] + 1) + i] = 4'd1;
            end
            length = 8'd(current_counts[0] + current_counts[1] + current_counts[2] + current_counts[3]);
          end
        end
      end
    end

    // Assign outputs
    if (valid) begin
      seq_out_0 = seq[0];
      seq_out_1 = seq[1];
      seq_out_2 = seq[2];
      seq_out_3 = seq[3];
      seq_out_4 = seq[4];
      seq_out_5 = seq[5];
      seq_out_6 = seq[6];
      seq_out_7 = seq[7];
      seq_out_8 = seq[8];
      seq_out_9 = seq[9];
      seq_out_10 = seq[10];
      seq_out_11 = seq[11];
      seq_out_12 = seq[12];
      seq_out_13 = seq[13];
      seq_out_14 = seq[14];
      seq_out_15 = seq[15];
    end else begin
      seq_out_0 = 4'd0;
      seq_out_1 = 4'd0;
      seq_out_2 = 4'd0;
      seq_out_3 = 4'd0;
      seq_out_4 = 4'd0;
      seq_out_5 = 4'd0;
      seq_out_6 = 4'd0;
      seq_out_7 = 4'd0;
      seq_out_8 = 4'd0;
      seq_out_9 = 4'd0;
      seq_out_10 = 4'd0;
      seq_out_11 = 4'd0;
      seq_out_12 = 4'd0;
      seq_out_13 = 4'd0;
      seq_out_14 = 4'd0;
      seq_out_15 = 4'd0;
    end
  end

endmodule