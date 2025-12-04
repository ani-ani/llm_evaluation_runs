module bat_spell_optimizer(
  input clk,
  input rst_n,
  input start,
  input [3:0] S,
  input [7:0] steps,
  output reg [7:0] result,
  output reg done
);

  reg [3:0] step_count;
  reg computing;
  wire [15:0] modulus = (1 << S);
  wire [15:0] mod_mask = modulus - 1;
  
  // Unit arrays for computation
  reg [15:0] power_arr [0:255];
  reg [7:0] mask_arr [0:255];
  
  // Pipelined comparison arrays
  reg [7:0] lvl0_mask [0:255];
  reg [15:0] lvl0_power [0:255];
  reg [7:0] lvl1_mask [0:127];
  reg [15:0] lvl1_power [0:127];
  reg [7:0] lvl2_mask [0:63];
  reg [15:0] lvl2_power [0:63];
  reg [7:0] lvl3_mask [0:31];
  reg [15:0] lvl3_power [0:31];
  reg [7:0] lvl4_mask [0:15];
  reg [15:0] lvl4_power [0:15];
  reg [7:0] lvl5_mask [0:7];
  reg [15:0] lvl5_power [0:7];
  reg [7:0] lvl6_mask [0:3];
  reg [15:0] lvl6_power [0:3];
  reg [7:0] lvl7_mask [0:1];
  reg [15:0] lvl7_power [0:1];
  reg [7:0] lvl8_mask;
  reg [15:0] lvl8_power;
  
  integer i;
  integer j;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      result <= 8'b0;
      step_count <= 4'b0;
      computing <= 1'b0;
    end else begin
      if (start) begin
        step_count <= 4'b0;
        computing <= 1'b1;
        done <= 1'b0;
        result <= 8'b0;
        // Initialize all units
        for (i=0; i<256; i=i+1) begin
          power_arr[i] <= 16'd1;
          mask_arr[i] <= i[7:0];
        end
      end else if (computing) begin
        if (step_count < 8) begin
          // Processing phase (cycles 0-7)
          for (i=0; i<256; i=i+1) begin
            if (mask_arr[i][7 - step_count]) begin // MSB (step0) first!
              if (steps[7 - step_count] == 1'b0) begin
                power_arr[i] <= (power_arr[i] + 1) & mod_mask;
              end else begin
                power_arr[i] <= (power_arr[i] << 1) & mod_mask;
              end
            end
            // Else: power_arr remains unchanged for skip
          end
          step_count <= step_count + 1;
        end else if (step_count < 16) begin
          // Comparison phase (cycles 8-15)
          step_count <= step_count + 1;
          case (step_count)
            4'd8: begin // Level 0 -> 1 (256 -> 128)
              for (i=0; i<128; i=i+1) begin
                lvl0_power[i*2] = power_arr[i*2];
                lvl0_mask[i*2] = mask_arr[i*2];
                lvl0_power[i*2+1] = power_arr[i*2+1];
                lvl0_mask[i*2+1] = mask_arr[i*2+1];
                
                if (lvl0_power[i*2] > lvl0_power[i*2+1]) begin
                  lvl1_power[i] <= lvl0_power[i*2];
                  lvl1_mask[i] <= lvl0_mask[i*2];
                end else if (lvl0_power[i*2+1] > lvl0_power[i*2]) begin
                  lvl1_power[i] <= lvl0_power[i*2+1];
                  lvl1_mask[i] <= lvl0_mask[i*2+1];
                end else begin
                  // Tie-breaker: max mask
                  if (lvl0_mask[i*2] >= lvl0_mask[i*2+1]) begin
                    lvl1_power[i] <= lvl0_power[i*2];
                    lvl1_mask[i] <= lvl0_mask[i*2];
                  end else begin
                    lvl1_power[i] <= lvl0_power[i*2+1];
                    lvl1_mask[i] <= lvl0_mask[i*2+1];
                  end
                end
              end
            end
            4'd9: begin // Level 1 -> 2 (128 -> 64)
              for (i=0; i<64; i=i+1) begin
                if (lvl1_power[i*2] > lvl1_power[i*2+1]) begin
                  lvl2_power[i] <= lvl1_power[i*2];
                  lvl2_mask[i] <= lvl1_mask[i*2];
                end else if (lvl1_power[i*2+1] > lvl1_power[i*2]) begin
                  lvl2_power[i] <= lvl1_power[i*2+1];
                  lvl2_mask[i] <= lvl1_mask[i*2+1];
                end else begin
                  if (lvl1_mask[i*2] >= lvl1_mask[i*2+1]) begin
                    lvl2_power[i] <= lvl1_power[i*2];
                    lvl2_mask[i] <= lvl1_mask[i*2];
                  end else begin
                    lvl2_power[i] <= lvl1_power[i*2+1];
                    lvl2_mask[i] <= lvl1_mask[i*2+1];
                  end
                end
              end
            end
            4'd10: begin // Level 2 -> 3 (64 -> 32)
              for (i=0; i<32; i=i+1) begin
                if (lvl2_power[i*2] > lvl2_power[i*2+1]) begin
                  lvl3_power[i] <= lvl2_power[i*2];
                  lvl3_mask[i] <= lvl2_mask[i*2];
                end else if (lvl2_power[i*2+1] > lvl2_power[i*2]) begin
                  lvl3_power[i] <= lvl2_power[i*2+1];
                  lvl3_mask[i] <= lvl2_mask[i*2+1];
                end else begin
                  if (lvl2_mask[i*2] >= lvl2_mask[i*2+1]) begin
                    lvl3_power[i] <= lvl2_power[i*2];
                    lvl3_mask[i] <= lvl2_mask[i*2];
                  end else begin
                    lvl3_power[i] <= lvl2_power[i*2+1];
                    lvl3_mask[i] <= lvl2_mask[i*2+1];
                  end
                end
              end
            end
            4'd11: begin // Level 3 -> 4 (32 -> 16)
              for (i=0; i<16; i=i+1) begin
                if (lvl3_power[i*2] > lvl3_power[i*2+1]) begin
                  lvl4_power[i] <= lvl3_power[i*2];
                  lvl4_mask[i] <= lvl3_mask[i*2];
                end else if (lvl3_power[i*2+1] > lvl3_power[i*2]) begin
                  lvl4_power[i] <= lvl3_power[i*2+1];
                  lvl4_mask[i] <= lvl3_mask[i*2+1];
                end else begin
                  if (lvl3_mask[i*2] >= lvl3_mask[i*2+1]) begin
                    lvl4_power[i] <= lvl3_power[i*2];
                    lvl4_mask[i] <= lvl3_mask[i*2];
                  end else begin
                    lvl4_power[i] <= lvl3_power[i*2+1];
                    lvl4_mask[i] <= lvl3_mask[i*2+1];
                  end
                end
              end
            end
            4'd12: begin // Level 4 -> 5 (16 -> 8)
              for (i=0; i<8; i=i+1) begin
                if (lvl4_power[i*2] > lvl4_power[i*2+1]) begin
                  lvl5_power[i] <= lvl4_power[i*2];
                  lvl5_mask[i] <= lvl4_mask[i*2];
                end else if (lvl4_power[i*2+1] > lvl4_power[i*2]) begin
                  lvl5_power[i] <= lvl4_power[i*2+1];
                  lvl5_mask[i] <= lvl4_mask[i*2+1];
                end else begin
                  if (lvl4_mask[i*2] >= lvl4_mask[i*2+1]) begin
                    lvl5_power[i] <= lvl4_power[i*2];
                    lvl5_mask[i] <= lvl4_mask[i*2];
                  end else begin
                    lvl5_power[i] <= lvl4_power[i*2+1];
                    lvl5_mask[i] <= lvl4_mask[i*2+1];
                  end
                end
              end
            end
            4'd13: begin // Level 5 -> 6 (8 -> 4)
              for (i=0; i<4; i=i+1) begin
                if (lvl5_power[i*2] > lvl5_power[i*2+1]) begin
                  lvl6_power[i] <= lvl5_power[i*2];
                  lvl6_mask[i] <= lvl5_mask[i*2];
                end else if (lvl5_power[i*2+1] > lvl5_power[i*2]) begin
                  lvl6_power[i] <= lvl5_power[i*2+1];
                  lvl6_mask[i] <= lvl5_mask[i*2+1];
                end else begin
                  if (lvl5_mask[i*2] >= lvl5_mask[i*2+1]) begin
                    lvl6_power[i] <= lvl5_power[i*2];
                    lvl6_mask[i] <= lvl5_mask[i*2];
                  end else begin
                    lvl6_power[i] <= lvl5_power[i*2+1];
                    lvl6_mask[i] <= lvl5_mask[i*2+1];
                  end
                end
              end
            end
            4'd14: begin // Level 6 -> 7 (4 -> 2)
              for (i=0; i<2; i=i+1) begin
                if (lvl6_power[i*2] > lvl6_power[i*2+1]) begin
                  lvl7_power[i] <= lvl6_power[i*2];
                  lvl7_mask[i] <= lvl6_mask[i*2];
                end else if (lvl6_power[i*2+1] > lvl6_power[i*2]) begin
                  lvl7_power[i] <= lvl6_power[i*2+1];
                  lvl7_mask[i] <= lvl6_mask[i*2+1];
                end else begin
                  if (lvl6_mask[i*2] >= lvl6_mask[i*2+1]) begin
                    lvl7_power[i] <= lvl6_power[i*2];
                    lvl7_mask[i] <= lvl6_mask[i*2];
                  end else begin
                    lvl7_power[i] <= lvl6_power[i*2+1];
                    lvl7_mask[i] <= lvl6_mask[i*2+1];
                  end
                end
              end
            end
            4'd15: begin // Level 7 -> 8 (2 -> 1)
              if (lvl7_power[0] > lvl7_power[1]) begin
                lvl8_power <= lvl7_power[0];
                lvl8_mask <= lvl7_mask[0];
              end else if (lvl7_power[1] > lvl7_power[0]) begin
                lvl8_power <= lvl7_power[1];
                lvl8_mask <= lvl7_mask[1];
              end else begin
                if (lvl7_mask[0] >= lvl7_mask[1]) begin
                  lvl8_power <= lvl7_power[0];
                  lvl8_mask <= lvl7_mask[0];
                end else begin
                  lvl8_power <= lvl7_power[1];
                  lvl8_mask <= lvl7_mask[1];
                end
              end
              result <= lvl8_mask;
              done <= 1'b1;
              computing <= 1'b0;
            end
          endcase
        end else
          computing <= 1'b0;
      end
    end
  end
endmodule