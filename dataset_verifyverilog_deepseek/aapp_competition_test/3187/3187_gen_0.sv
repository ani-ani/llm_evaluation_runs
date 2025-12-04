module protest_location_optimizer(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [7:0] data_x [0:7],
  input [7:0] data_y [0:7],
  input [7:0] d,
  output reg [11:0] total_distance,
  output reg impossible,
  output reg done
);

  // Internal registers
  reg [7:0] data_x_reg [0:7];
  reg [7:0] data_y_reg [0:7];
  reg [2:0] n_reg;
  reg [7:0] d_reg;
  reg [7:0] sorted_x [0:7];
  reg [7:0] sorted_y [0:7];
  reg [7:0] x_med, y_med;
  reg [8:0] distance [0:7];
  reg [4:0] counter;
  reg prev_start;
  reg all_within;
  reg [11:0] total_sum;

  // Start pulse detection
  wire start_pulse = start && !prev_start;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Clear outputs
      total_distance <= 12'h0;
      impossible <= 1'b0;
      done <= 1'b0;

      // Clear internal registers
      foreach (data_x_reg[i]) data_x_reg[i] <= 8'h0;
      foreach (data_y_reg[i]) data_y_reg[i] <= 8'h0;
      n_reg <= 3'h0;
      d_reg <= 8'h0;
      foreach (sorted_x[i]) sorted_x[i] <= 8'h0;
      foreach (sorted_y[i]) sorted_y[i] <= 8'h0;
      x_med <= 8'h0;
      y_med <= 8'h0;
      foreach (distance[i]) distance[i] <= 9'h0;
      counter <= 5'h1F;
      prev_start <= 1'b0;
      all_within <= 1'b0;
      total_sum <= 12'h0;
    end else begin
      prev_start <= start;
      done <= 1'b0;

      // Start computation
      if (start_pulse && counter > 19) begin
        counter <= 5'h0;
        data_x_reg <= data_x;
        data_y_reg <= data_y;
        n_reg <= n;
        d_reg <= d;
        sorted_x <= data_x;
        sorted_y <= data_y;
      end else if (counter < 19) begin
        counter <= counter + 5'h1;
      end

      // Processing pipeline
      case (counter)
        // Sorting stages (Batchera's 8-element)
        5'h1: begin  // Stage 1
          for (int i=0; i<8; i+=2) begin
            if (sorted_x[i] > sorted_x[i+1]) {sorted_x[i], sorted_x[i+1]} <= {sorted_x[i+1], sorted_x[i]};
            if (sorted_y[i] > sorted_y[i+1]) {sorted_y[i], sorted_y[i+1]} <= {sorted_y[i+1], sorted_y[i]};
          end
        end
        5'h2: begin  // Stage 2
          for (int i=0; i<8; i+=4) begin
            if (sorted_x[i] > sorted_x[i+2]) {sorted_x[i], sorted_x[i+2]} <= {sorted_x[i+2], sorted_x[i]};
            if (sorted_x[i+1] > sorted_x[i+3]) {sorted_x[i+1], sorted_x[i+3]} <= {sorted_x[i+3], sorted_x[i+1]};
            if (sorted_y[i] > sorted_y[i+2]) {sorted_y[i], sorted_y[i+2]} <= {sorted_y[i+2], sorted_y[i]};
            if (sorted_y[i+1] > sorted_y[i+3]) {sorted_y[i+1], sorted_y[i+3]} <= {sorted_y[i+3], sorted_y[i+1]};
          end
        end
        5'h3: begin  // Stage 3
          if (sorted_x[1] > sorted_x[2]) {sorted_x[1], sorted_x[2]} <= {sorted_x[2], sorted_x[1]};
          if (sorted_y[5] > sorted_y[6]) {sorted_y[5], sorted_y[6]} <= {sorted_y[6], sorted_y[5]};
          if (sorted_x[0] > sorted_x[4]) {sorted_x[0], sorted_x[4]} <= {sorted_x[4], sorted_x[0]};
          if (sorted_y[3] > sorted_y[7]) {sorted_y[3], sorted_y[7]} <= {sorted_y[7], sorted_y[3]};
        end
        5'h4: begin  // Stage 4
          if (sorted_x[1] > sorted_x[4]) {sorted_x[1], sorted_x[4]} <= {sorted_x[4], sorted_x[1]};
          if (sorted_x[3] > sorted_x[6]) {sorted_x[3], sorted_x[6]} <= {sorted_x[6], sorted_x[3]};
          if (sorted_y[1] > sorted_y[4]) {sorted_y[1], sorted_y[4]} <= {sorted_y[4], sorted_y[1]};
          if (sorted_y[3] > sorted_y[6]) {sorted_y[3], sorted_y[6]} <= {sorted_y[6], sorted_y[3]};
        end
        5'h5: begin  // Stage 5
          if (sorted_x[2] > sorted_x[4]) {sorted_x[2], sorted_x[4]} <= {sorted_x[4], sorted_x[2]};
          if (sorted_x[3] > sorted_x[5]) {sorted_x[3], sorted_x[5]} <= {sorted_x[5], sorted_x[3]};
          if (sorted_y[2] > sorted_y[4]) {sorted_y[2], sorted_y[4]} <= {sorted_y[4], sorted_y[2]};
          if (sorted_y[3] > sorted_y[5]) {sorted_y[3], sorted_y[5]} <= {sorted_y[5], sorted_y[3]};
        end
        5'h6: begin  // Stage 6
          if (sorted_x[3] > sorted_x[4]) {sorted_x[3], sorted_x[4]} <= {sorted_x[4], sorted_x[3]};
          if (sorted_y[3] > sorted_y[4]) {sorted_y[3], sorted_y[4]} <= {sorted_y[4], sorted_y[3]};
        end

        // Medians
        5'h7: begin
          x_med <= sorted_x[3];
          y_med <= sorted_y[3];
        end

        // Individual distances
        5'h8: begin
          for (int i=0; i<8; i++) begin
            distance[i] <= 
              (data_x_reg[i] < x_med ? x_med - data_x_reg[i] : data_x_reg[i] - x_med) +
              (data_y_reg[i] < y_med ? y_med - data_y_reg[i] : data_y_reg[i] - y_med);
          end
        end

        // Validation
        5'h9: begin
          all_within <= 1'b1;
          total_sum <= 12'h0;

          for (int i=0; i<8; i++) begin
            if (i < n_reg) begin
              if (distance[i] > d_reg) all_within <= 1'b0;
              total_sum <= total_sum + distance[i];
            end
          end
        end

        // Final output
        5'h13: begin
          total_distance <= all_within ? total_sum : 12'h0;
          impossible <= !all_within;
          done <= 1'b1;
        end
      endcase
    end
  end

endmodule