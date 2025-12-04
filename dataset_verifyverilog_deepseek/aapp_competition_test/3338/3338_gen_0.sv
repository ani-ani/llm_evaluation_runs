module partner_diversity(
  input clk,
  input rst_n,
  input start,
  input [7:0] partner0_g, input [7:0] partner0_p, input [7:0] partner0_ga, input [7:0] partner0_pa,
  input [7:0] partner1_g, input [7:0] partner1_p, input [7:0] partner1_ga, input [7:0] partner1_pa,
  input [7:0] partner2_g, input [7:0] partner2_p, input [7:0] partner2_ga, input [7:0] partner2_pa,
  input [7:0] partner3_g, input [7:0] partner3_p, input [7:0] partner3_ga, input [7:0] partner3_pa,
  input [1:0] k,
  output reg [2:0] diversity,
  output reg done
);

  reg [1:0] state;
  reg [4:0] counter;
  reg [2:0] max_diversity_reg;
  reg [3:0] current_comb;
  reg [7:0] partner_frag [0:3];
  reg [7:0] partner_step [0:3];
  reg [2:0] awaken_count;
  reg conflict_01, conflict_02, conflict_03, conflict_12, conflict_13, conflict_23;
  wire all_conflict_or = conflict_01 | conflict_02 | conflict_03 | conflict_12 | conflict_13 | conflict_23;
  reg size4_valid;
  reg [3:0] size3_valid;
  reg any_size3_valid;
  reg size2_valid;
  reg [2:0] max_size_curr;

  localparam IDLE = 2'b00, CALCULATING = 2'b01, DONE = 2'b10;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      counter <= 5'd0;
      max_diversity_reg <= 3'd0;
      diversity <= 3'd0;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            state <= CALCULATING;
            counter <= 5'd0;
            max_diversity_reg <= 3'd0;
          end
        end

        CALCULATING: begin
          if (counter < 5'd20) begin
            current_comb <= counter[3:0];
            counter <= counter + 1;
            
            if (counter[3:0] < 4'd16) begin
              awaken_count <= current_comb[0] + current_comb[1] + current_comb[2] + current_comb[3];
              if (awaken_count <= k) begin
                partner_frag[0] <= current_comb[0] ? partner0_ga : partner0_g;
                partner_step[0] <= current_comb[0] ? partner0_pa : partner0_p;
                partner_frag[1] <= current_comb[1] ? partner1_ga : partner1_g;
                partner_step[1] <= current_comb[1] ? partner1_pa : partner1_p;
                partner_frag[2] <= current_comb[2] ? partner2_ga : partner2_g;
                partner_step[2] <= current_comb[2] ? partner2_pa : partner2_p;
                partner_frag[3] <= current_comb[3] ? partner3_ga : partner3_g;
                partner_step[3] <= current_comb[3] ? partner3_pa : partner3_p;

                // Compute conflicts
                conflict_01 <= ((partner_frag[0] > partner_frag[1]) && (partner_step[0] > partner_step[1])) || 
                              ((partner_frag[1] > partner_frag[0]) && (partner_step[1] > partner_step[0]));
                conflict_02 <= ((partner_frag[0] > partner_frag[2]) && (partner_step[0] > partner_step[2])) || 
                              ((partner_frag[2] > partner_frag[0]) && (partner_step[2] > partner_step[0]));
                conflict_03 <= ((partner_frag[0] > partner_frag[3]) && (partner_step[0] > partner_step[3])) || 
                              ((partner_frag[3] > partner_frag[0]) && (partner_step[3] > partner_step[0]));
                conflict_12 <= ((partner_frag[1] > partner_frag[2]) && (partner_step[1] > partner_step[2])) || 
                              ((partner_frag[2] > partner_frag[1]) && (partner_step[2] > partner_step[1]));
                conflict_13 <= ((partner_frag[1] > partner_frag[3]) && (partner_step[1] > partner_step[3])) || 
                              ((partner_frag[3] > partner_frag[1]) && (partner_step[3] > partner_step[1]));
                conflict_23 <= ((partner_frag[2] > partner_frag[3]) && (partner_step[2] > partner_step[3])) || 
                              ((partner_frag[3] > partner_frag[2]) && (partner_step[3] > partner_step[2]));

                size4_valid <= !all_conflict_or;
                
                size3_valid[0] <= !(conflict_01 || conflict_02 || conflict_12);
                size3_valid[1] <= !(conflict_01 || conflict_03 || conflict_13);
                size3_valid[2] <= !(conflict_02 || conflict_03 || conflict_23);
                size3_valid[3] <= !(conflict_12 || conflict_13 || conflict_23);
                any_size3_valid <= |size3_valid;
                
                size2_valid <= !conflict_01 || !conflict_02 || !conflict_03 || !conflict_12 || !conflict_13 || !conflict_23;

                if (size4_valid)
                  max_size_curr <= 3'd4;
                else if (any_size3_valid)
                  max_size_curr <= 3'd3;
                else if (size2_valid)
                  max_size_curr <= 3'd2;
                else
                  max_size_curr <= 3'd1;

                if (max_size_curr > max_diversity_reg)
                  max_diversity_reg <= max_size_curr;
              end
            end
          end else begin
            state <= DONE;
          end
        end

        DONE: begin
          diversity <= max_diversity_reg;
          done <= 1'b1;
          if (!start) state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule