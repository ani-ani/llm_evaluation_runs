module remove_duplicates(
  input logic clk,
  input logic rst_n,
  input logic start,
  input logic [3:0] data_in [7:0],
  output logic [3:0] data_out [7:0],
  output logic [7:0] valid_mask,
  output logic done
);

  // internal signals
  logic start_sync, start_pulse;
  logic [3:0] data_reg [7:0];
  logic [3:0] freq [15:0];
  logic [2:0] cnt;
  logic counting;
  logic count_done;
  logic [3:0] data_out_reg [7:0];
  logic [7:0] valid_mask_reg;
  logic done_reg;

  // Rising edge detection for start
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_sync <= 1'b0;
      start_pulse <= 1'b0;
    end else begin
      start_sync <= start;
      start_pulse <= (~start_sync) & start; // 1-cycle pulse on rising edge
    end
  end

  // Capture the input array when a new start is received
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_reg <= '{default:'0};
    end else begin
      if (start_pulse) begin
        data_reg <= data_in;
      end
    end
  end

  // Frequency counter for each 4-bit value (0-15)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      freq <= '{default:'0};
    end else begin
      if (start_pulse) begin
        freq <= '{default:'0};
      end else if (counting) begin
        freq[data_reg[cnt]] <= freq[data_reg[cnt]] + 1;
      end
    end
  end

  // Counter to iterate over the 8 input elements
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt <= 3'd0;
      counting <= 1'b0;
    end else begin
      if (start_pulse) begin
        counting <= 1'b1;
        cnt <= 3'd0;
      end else if (counting) begin
        if (cnt == 3'd7) begin
          counting <= 1'b0;
        end
        cnt <= cnt + 1;
      end
    end
  end

  // Asserted on the last counting cycle (when the 8th element is processed)
  assign count_done = counting && (cnt == 3'd7);

  // Output registers - populated once counting is finished
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_out_reg <= '{default:'0};
      valid_mask_reg <= 8'b0;
      done_reg <= 1'b0;
    end else begin
      if (start_pulse) begin
        // clear outputs for a new run
        data_out_reg <= '{default:'0};
        valid_mask_reg <= 8'b0;
        done_reg <= 1'b0;
      end else if (count_done) begin
        for (int i = 0; i < 8; i++) begin
          if (freq[data_reg[i]] == 4'd1) begin
            data_out_reg[i] <= data_reg[i];
            valid_mask_reg[i] <= 1'b1;
          end else begin
            data_out_reg[i] <= 4'd0;
            valid_mask_reg[i] <= 1'b0;
          end
        end
        done_reg <= 1'b1;
      end
    end
  end

  // Drive module outputs
  assign data_out = data_out_reg;
  assign valid_mask = valid_mask_reg;
  assign done = done_reg;

endmodule