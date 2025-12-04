module tape_art_decoder(input clk, input rst_n, input start, input [3:0] n, input [3:0] c[0:15],
  output reg [3:0] instr_l[0:15], output reg [3:0] instr_r[0:15], output reg [3:0] instr_c[0:15],
  output reg [4:0] instr_count, output reg done, output reg impossible);

  enum logic [3:0] { IDLE, SCAN_FIRST_LAST, CHECK_CONSISTENCY, BUILD_INSTRUCTIONS, DONE } state;
  reg [3:0] first[0:15]; // First occurrence per color (0-15)
  reg [3:0] last[0:15];  // Last occurrence per color
  reg [15:0] valid_color; // Valid colors (first <= last)
  reg [4:0] pos_counter;  // Position scanning counter (0-15)
  reg [3:0] build_idx;    // Instruction build index
  reg [15:0] rem_colors;  // Remaining colors during building
  reg impossible_comb;     // Combinational impossible flag

  // Consistency check combinational logic
  always_comb begin
    impossible_comb = 1'b0;
    for (int i = 0; i < 16; i++) begin
      if (i < n) begin
        logic [3:0] eff_color = 4'h0;
        logic [3:0] max_last = 4'h0;
        for (int j = 0; j < 16; j++) begin
          if (first[j] <= i && i <= last[j] && last[j] >= max_last) begin
            max_last = last[j];
            eff_color = j;
          end
        end
        if (eff_color !== c[i]) impossible_comb = 1'b1;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      impossible <= 1'b0;
      state <= IDLE;
      pos_counter <= 5'd0;
      build_idx <= 4'd0;
      instr_count <= 5'd0;
      for (int i=0; i<16; i++) begin
        instr_l[i] <= 4'd0;
        instr_r[i] <= 4'd0;
        instr_c[i] <= 4'd0;
      end
    end else begin
      done <= 1'b0;
      case (state)
        IDLE: begin
          impossible <= 1'b0;
          if (start) begin
            for (int i=0; i<16; i++) first[i] <= 4'hF; // Initialize with invalid index
            for (int i=0; i<16; i++) last[i] <= 4'h0;
            pos_counter <= 5'd0;
            state <= SCAN_FIRST_LAST;
          end
        end

        SCAN_FIRST_LAST: begin
          if (pos_counter < n) begin
            automatic logic [3:0] color = c[pos_counter];
            if (first[color] == 4'hF) first[color] <= pos_counter[3:0];
            last[color] <= pos_counter[3:0];
            pos_counter <= pos_counter + 1;
          end else begin
            // Mark valid colors (first <= last)
            for (int i=0; i<16; i++)
              valid_color[i] <= (first[i] <= last[i]);
            state <= CHECK_CONSISTENCY;
          end
        end

        CHECK_CONSISTENCY: begin
          impossible <= impossible_comb;
          if (impossible_comb) state <= DONE;
          else begin
            rem_colors <= valid_color;
            build_idx <= 4'd0;
            instr_count <= 5'd0;
            state <= BUILD_INSTRUCTIONS;
          end
        end

        BUILD_INSTRUCTIONS: begin
          automatic logic [3:0] max_last = 4'h0;
          automatic logic [3:0] max_col = 4'h0;
          for (int i=0; i<16; i++) begin
            if (rem_colors[i] && last[i] > max_last) begin
              max_last = last[i];
              max_col = i;
            end
          end
          if (max_last != 4'h0) begin
            instr_l[build_idx] <= first[max_col];
            instr_r[build_idx] <= last[max_col];
            instr_c[build_idx] <= max_col;
            rem_colors[max_col] <= 1'b0;
            instr_count <= instr_count + 1;
            build_idx <= build_idx + 1;
          end else begin
            state <= DONE;
          end
        end

        DONE: begin
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule