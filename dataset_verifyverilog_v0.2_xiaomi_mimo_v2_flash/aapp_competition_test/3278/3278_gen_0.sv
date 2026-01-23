module frog_tower (
    input clk,
    input rst_n,
    input start,
    input [5:0] frog_count,
    input [15:0] frog_data [0:15],
    output reg [7:0] tower_position,
    output reg [7:0] tower_size,
    output reg done
);

    // States
    localparam IDLE = 2'b00;
    localparam LOAD_FROGS = 2'b01;
    localparam FIND_MAX_TOWER = 2'b10;
    localparam DONE_STATE = 2'b11;

    // Registers
    reg [1:0] state, next_state;
    reg [5:0] stored_count;
    reg [15:0] frogs [0:15];
    reg [7:0] pos_reg;
    reg [7:0] temp_count;
    reg [7:0] max_count;
    reg [7:0] max_pos;
    reg [5:0] frog_idx;
    reg [4:0] load_idx;
    
    // Intermediate calculation registers
    reg [7:0] x_val;
    reg [7:0] d_val;
    reg [7:0] diff;
    reg [7:0] mod_result;
    reg div_done;
    
    // Combinational signals
    wire pos_valid;
    wire [7:0] diff_wire;
    
    assign diff_wire = pos_reg - x_val;
    
    // Modulo calculation (combinational for small primes)
    always @(*) begin
        d_val = frogs[frog_idx][7:0];
        x_val = frogs[frog_idx][15:8];
        diff = diff_wire;
        
        // Calculate diff % d_val
        case(d_val)
            8'd2: mod_result = diff[0];
            8'd3: begin
                // Simple 8-bit modulo 3 logic
                if (diff < 8'd3) mod_result = diff;
                else if (diff < 8'd6) mod_result = diff - 8'd3;
                else if (diff < 8'd9) mod_result = diff - 8'd6;
                else if (diff < 8'd12) mod_result = diff - 8'd9;
                else if (diff < 8'd15) mod_result = diff - 8'd12;
                else if (diff < 8'd18) mod_result = diff - 8'd15;
                else if (diff < 8'd21) mod_result = diff - 8'd18;
                else if (diff < 8'd24) mod_result = diff - 8'd21;
                else if (diff < 8'd27) mod_result = diff - 8'd24;
                else if (diff < 8'd30) mod_result = diff - 8'd27;
                else if (diff < 8'd33) mod_result = diff - 8'd30;
                else if (diff < 8'd36) mod_result = diff - 8'd33;
                else if (diff < 8'd39) mod_result = diff - 8'd36;
                else if (diff < 8'd42) mod_result = diff - 8'd39;
                else if (diff < 8'd45) mod_result = diff - 8'd42;
                else if (diff < 8'd48) mod_result = diff - 8'd45;
                else if (diff < 8'd51) mod_result = diff - 8'd48;
                else if (diff < 8'd54) mod_result = diff - 8'd51;
                else if (diff < 8'd57) mod_result = diff - 8'd54;
                else if (diff < 8'd60) mod_result = diff - 8'd57;
                else if (diff < 8'd63) mod_result = diff - 8'd60;
                else if (diff < 8'd66) mod_result = diff - 8'd63;
                else if (diff < 8'd69) mod_result = diff - 8'd66;
                else if (diff < 8'd72) mod_result = diff - 8'd69;
                else if (diff < 8'd75) mod_result = diff - 8'd72;
                else if (diff < 8'd78) mod_result = diff - 8'd75;
                else if (diff < 8'd81) mod_result = diff - 8'd78;
                else if (diff < 8'd84) mod_result = diff - 8'd81;
                else if (diff < 8'd87) mod_result = diff - 8'd84;
                else if (diff < 8'd90) mod_result = diff - 8'd87;
                else if (diff < 8'd93) mod_result = diff - 8'd90;
                else if (diff < 8'd96) mod_result = diff - 8'd93;
                else if (diff < 8'd99) mod_result = diff - 8'd96;
                else if (diff < 8'd102) mod_result = diff - 8'd99;
                else if (diff < 8'd105) mod_result = diff - 8'd102;
                else if (diff < 8'd108) mod_result = diff - 8'd105;
                else if (diff < 8'd111) mod_result = diff - 8'd108;
                else if (diff < 8'd114) mod_result = diff - 8'd111;
                else if (diff < 8'd117) mod_result = diff - 8'd114;
                else if (diff < 8'd120) mod_result = diff - 8'd117;
                else if (diff < 8'd123) mod_result = diff - 8'd120;
                else if (diff < 8'd126) mod_result = diff - 8'd123;
                else if (diff < 8'd129) mod_result = diff - 8'd126;
                else if (diff < 8'd132) mod_result = diff - 8'd129;
                else if (diff < 8'd135) mod_result = diff - 8'd132;
                else if (diff < 8'd138) mod_result = diff - 8'd135;
                else if (diff < 8'd141) mod_result = diff - 8'd138;
                else if (diff < 8'd144) mod_result = diff - 8'd141;
                else if (diff < 8'd147) mod_result = diff - 8'd144;
                else if (diff < 8'd150) mod_result = diff - 8'd147;
                else if (diff < 8'd153) mod_result = diff - 8'd150;
                else if (diff < 8'd156) mod_result = diff - 8'd153;
                else if (diff < 8'd159) mod_result = diff - 8'd156;
                else if (diff < 8'd162) mod_result = diff - 8'd159;
                else if (diff < 8'd165) mod_result = diff - 8'd162;
                else if (diff < 8'd168) mod_result = diff - 8'd165;
                else if (diff < 8'd171) mod_result = diff - 8'd168;
                else if (diff < 8'd174) mod_result = diff - 8'd171;
                else if (diff < 8'd177) mod_result = diff - 8'd174;
                else if (diff < 8'd180) mod_result = diff - 8'd177;
                else if (diff < 8'd183) mod_result = diff - 8'd180;
                else if (diff < 8'd186) mod_result = diff - 8'd183;
                else if (diff < 8'd189) mod_result = diff - 8'd186;
                else if (diff < 8'd192) mod_result = diff - 8'd189;
                else if (diff < 8'd195) mod_result = diff - 8'd192;
                else if (diff < 8'd198) mod_result = diff - 8'd195;
                else if (diff < 8'd201) mod_result = diff - 8'd198;
                else if (diff < 8'd204) mod_result = diff - 8'd201;
                else if (diff < 8'd207) mod_result = diff - 8'd204;
                else if (diff < 8'd210) mod_result = diff - 8'd207;
                else if (diff < 8'd213) mod_result = diff - 8'd210;
                else if (diff < 8'd216) mod_result = diff - 8'd213;
                else if (diff < 8'd219) mod_result = diff - 8'd216;
                else if (diff < 8'd222) mod_result = diff - 8'd219;
                else if (diff < 8'd225) mod_result = diff - 8'd222;
                else if (diff < 8'd228) mod_result = diff - 8'd225;
                else if (diff < 8'd231) mod_result = diff - 8'd228;
                else if (diff < 8'd234) mod_result = diff - 8'd231;
                else if (diff < 8'd237) mod_result = diff - 8'd234;
                else if (diff < 8'd240) mod_result = diff - 8'd237;
                else if (diff < 8'd243) mod_result = diff - 8'd240;
                else if (diff < 8'd246) mod_result = diff - 8'd243;
                else if (diff < 8'd249) mod_result = diff - 8'd246;
                else if (diff < 8'd252) mod_result = diff - 8'd249;
                else if (diff < 8'd255) mod_result = diff - 8'd252;
                else mod_result = diff - 8'd255;
            end
            8'd5: begin
                // diff % 5
                if (diff < 5) mod_result = diff;
                else if (diff < 10) mod_result = diff - 5;
                else if (diff < 15) mod_result = diff - 10;
                else if (diff < 20) mod_result = diff - 15;
                else if (diff < 25) mod_result = diff - 20;
                else if (diff < 30) mod_result = diff - 25;
                else if (diff < 35) mod_result = diff - 30;
                else if (diff < 40) mod_result = diff - 35;
                else if (diff < 45) mod_result = diff - 40;
                else if (diff < 50) mod_result = diff - 45;
                else if (diff < 55) mod_result = diff - 50;
                else if (diff < 60) mod_result = diff - 55;
                else if (diff < 65) mod_result = diff - 60;
                else if (diff < 70) mod_result = diff - 65;
                else if (diff < 75) mod_result = diff - 70;
                else if (diff < 80) mod_result = diff - 75;
                else if (diff < 85) mod_result = diff - 80;
                else if (diff < 90) mod_result = diff - 85;
                else if (diff < 95) mod_result = diff - 90;
                else if (diff < 100) mod_result = diff - 95;
                else if (diff < 105) mod_result = diff - 100;
                else if (diff < 110) mod_result = diff - 105;
                else if (diff < 115) mod_result = diff - 110;
                else if (diff < 120) mod_result = diff - 115;
                else if (diff < 125) mod_result = diff - 120;
                else if (diff < 130) mod_result = diff - 125;
                else if (diff < 135) mod_result = diff - 130;
                else if (diff < 140) mod_result = diff - 135;
                else if (diff < 145) mod_result = diff - 140;
                else if (diff < 150) mod_result = diff - 145;
                else if (diff < 155) mod_result = diff - 150;
                else if (diff < 160) mod_result = diff - 155;
                else if (diff < 165) mod_result = diff - 160;
                else if (diff < 170) mod_result = diff - 165;
                else if (diff < 175) mod_result = diff - 170;
                else if (diff < 180) mod_result = diff - 175;
                else if (diff < 185) mod_result = diff - 180;
                else if (diff < 190) mod_result = diff - 185;
                else if (diff < 195) mod_result = diff - 190;
                else if (diff < 200) mod_result = diff - 195;
                else if (diff < 205) mod_result = diff - 200;
                else if (diff < 210) mod_result = diff - 205;
                else if (diff < 215) mod_result = diff - 210;
                else if (diff < 220) mod_result = diff - 215;
                else if (diff < 225) mod_result = diff - 220;
                else if (diff < 230) mod_result = diff - 225;
                else if (diff < 235) mod_result = diff - 230;
                else if (diff < 240) mod_result = diff - 235;
                else if (diff < 245) mod_result = diff - 240;
                else if (diff < 250) mod_result = diff - 245;
                else mod_result = diff - 250;
            end
            8'd7: begin
                // diff % 7
                if (diff < 7) mod_result = diff;
                else if (diff < 14) mod_result = diff - 7;
                else if (diff < 21) mod_result = diff - 14;
                else if (diff < 28) mod_result = diff - 21;
                else if (diff < 35) mod_result = diff - 28;
                else if (diff < 42) mod_result = diff - 35;
                else if (diff < 49) mod_result = diff - 42;
                else if (diff < 56) mod_result = diff - 49;
                else if (diff < 63) mod_result = diff - 56;
                else if (diff < 70) mod_result = diff - 63;
                else if (diff < 77) mod_result = diff - 70;
                else if (diff < 84) mod_result = diff - 77;
                else if (diff < 91) mod_result = diff - 84;
                else if (diff < 98) mod_result = diff - 91;
                else if (diff < 105) mod_result = diff - 98;
                else if (diff < 112) mod_result = diff - 105;
                else if (diff < 119) mod_result = diff - 112;
                else if (diff < 126) mod_result = diff - 119;
                else if (diff < 133) mod_result = diff - 126;
                else if (diff < 140) mod_result = diff - 133;
                else if (diff < 147) mod_result = diff - 140;
                else if (diff < 154) mod_result = diff - 147;
                else if (diff < 161) mod_result = diff - 154;
                else if (diff < 168) mod_result = diff - 161;
                else if (diff < 175) mod_result = diff - 168;
                else if (diff < 182) mod_result = diff - 175;
                else if (diff < 189) mod_result = diff - 182;
                else if (diff < 196) mod_result = diff - 189;
                else if (diff < 203) mod_result = diff - 196;
                else if (diff < 210) mod_result = diff - 203;
                else if (diff < 217) mod_result = diff - 210;
                else if (diff < 224) mod_result = diff - 217;
                else if (diff < 231) mod_result = diff - 224;
                else if (diff < 238) mod_result = diff - 231;
                else if (diff < 245) mod_result = diff - 238;
                else if (diff < 252) mod_result = diff - 245;
                else mod_result = diff - 252;
            end
            8'd11: begin
                // diff % 11
                if (diff < 11) mod_result = diff;
                else if (diff < 22) mod_result = diff - 11;
                else if (diff < 33) mod_result = diff - 22;
                else if (diff < 44) mod_result = diff - 33;
                else if (diff < 55) mod_result = diff - 44;
                else if (diff < 66) mod_result = diff - 55;
                else if (diff < 77) mod_result = diff - 66;
                else if (diff < 88) mod_result = diff - 77;
                else if (diff < 99) mod_result = diff - 88;
                else if (diff < 110) mod_result = diff - 99;
                else if (diff < 121) mod_result = diff - 110;
                else if (diff < 132) mod_result = diff - 121;
                else if (diff < 143) mod_result = diff - 132;
                else if (diff < 154) mod_result = diff - 143;
                else if (diff < 165) mod_result = diff - 154;
                else if (diff < 176) mod_result = diff - 165;
                else if (diff < 187) mod_result = diff - 176;
                else if (diff < 198) mod_result = diff - 187;
                else if (diff < 209) mod_result = diff - 198;
                else if (diff < 220) mod_result = diff - 209;
                else if (diff < 231) mod_result = diff - 220;
                else if (diff < 242) mod_result = diff - 231;
                else if (diff < 253) mod_result = diff - 242;
                else mod_result = diff - 253;
            end
            8'd13: begin
                // diff % 13
                if (diff < 13) mod_result = diff;
                else if (diff < 26) mod_result = diff - 13;
                else if (diff < 39) mod_result = diff - 26;
                else if (diff < 52) mod_result = diff - 39;
                else if (diff < 65) mod_result = diff - 52;
                else if (diff < 78) mod_result = diff - 65;
                else if (diff < 91) mod_result = diff - 78;
                else if (diff < 104) mod_result = diff - 91;
                else if (diff < 117) mod_result = diff - 104;
                else if (diff < 130) mod_result = diff - 117;
                else if (diff < 143) mod_result = diff - 130;
                else if (diff < 156) mod_result = diff - 143;
                else if (diff < 169) mod_result = diff - 156;
                else if (diff < 182) mod_result = diff - 169;
                else if (diff < 195) mod_result = diff - 182;
                else if (diff < 208) mod_result = diff - 195;
                else if (diff < 221) mod_result = diff - 208;
                else if (diff < 234) mod_result = diff - 221;
                else if (diff < 247) mod_result = diff - 234;
                else mod_result = diff - 247;
            end
            default: mod_result = 8'hFF; // Should not happen for valid primes
        endcase
    end

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD_FROGS;
                else
                    next_state = IDLE;
            end
            LOAD_FROGS: begin
                if (load_idx >= frog_count || load_idx >= 16)
                    next_state = FIND_MAX_TOWER;
                else
                    next_state = LOAD_FROGS;
            end
            FIND_MAX_TOWER: begin
                if (pos_reg > 8'd255 && frog_idx >= stored_count)
                    next_state = DONE_STATE;
                else
                    next_state = FIND_MAX_TOWER;
            end
            DONE_STATE: begin
                next_state = DONE_STATE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stored_count <= 6'd0;
            load_idx <= 5'd0;
            pos_reg <= 8'd0;
            frog_idx <= 6'd0;
            temp_count <= 8'd0;
            max_count <= 8'd0;
            max_pos <= 8'd0;
            tower_position <= 8'd0;
            tower_size <= 8'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        load_idx <= 5'd0;
                        done <= 1'b0;
                        stored_count <= frog_count > 16 ? 16 : frog_count;
                        pos_reg <= 8'd0;
                        frog_idx <= 6'd0;
                        temp_count <= 8'd0;
                        max_count <= 8'd0;
                        max_pos <= 8'd0;
                    end
                end

                LOAD_FROGS: begin
                    if (load_idx < 16 && load_idx < frog_count) begin
                        frogs[load_idx] <= frog_data[load_idx];
                        load_idx <= load_idx + 1;
                    end
                end

                FIND_MAX_TOWER: begin
                    // Check if we are still within valid position range
                    if (pos_reg <= 8'd255) begin
                        // Count frogs for current position
                        if (frog_idx < stored_count) begin
                            if (frogs[frog_idx][15:8] <= pos_reg && mod_result == 0) begin
                                temp_count <= temp_count + 1;
                            end
                            frog_idx <= frog_idx + 1;
                        end else begin
                            // Finished counting for this position
                            frog_idx <= 6'd0; // Reset for next position
                            
                            // Update max if needed
                            if (temp_count > max_count) begin
                                max_count <= temp_count;
                                max_pos <= pos_reg;
                            end
                            temp_count <= 8'd0; // Reset temp count
                            pos_reg <= pos_reg + 1; // Move to next position
                        end
                    end else begin
                        // All positions checked, prepare output
                        if (frog_idx == 6'd0) begin
                            tower_position <= max_pos;
                            tower_size <= max_count;
                            done <= 1'b1;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
