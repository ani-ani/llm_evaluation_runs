module has_close_elements(
    input clk,
    input rst_n,
    input start,
    input [15:0] data_in,
    input [2:0] addr_in,
    input we,
    input [15:0] threshold,
    output reg result,
    output reg done
);

    // Internal storage for the 8-element array
    reg [15:0] array_reg [0:7];
    
    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] LOAD     = 3'd1;  // Latch threshold
    localparam [2:0] CALC_01  = 3'd2;  // Check pair (0,1)
    localparam [2:0] CALC_02  = 3'd3;  // Check pair (0,2)
    localparam [2:0] CALC_03  = 3'd4;  // Check pair (0,3)
    localparam [2:0] CALC_04  = 3'd5;  // Check pair (0,4)
    localparam [2:0] CALC_05  = 3'd6;  // Check pair (0,5)
    localparam [2:0] CALC_06  = 3'd7;  // Check pair (0,6)
    // Remaining pairs are calculated in parallel during CALC states
    // We need more states for pairs (0,7), (1,2), (1,3), (1,4), (1,5), (1,6), (1,7)
    // (2,3), (2,4), (2,5), (2,6), (2,7)
    // (3,4), (3,5), (3,6), (3,7)
    // (4,5), (4,6), (4,7)
    // (5,6), (5,7)
    // (6,7)
    // Total 28 pairs. With 10 cycle limit, we can do 3 pairs per cycle (parallel logic)
    // Let's reorganize: 9 states (IDLE + 8 calculation states)
    // State 2: Pairs (0,1), (0,2), (0,3)
    // State 3: Pairs (0,4), (0,5), (0,6)
    // State 4: Pairs (0,7), (1,2), (1,3)
    // State 5: Pairs (1,4), (1,5), (1,6)
    // State 6: Pairs (1,7), (2,3), (2,4)
    // State 7: Pairs (2,5), (2,6), (2,7)
    // State 8: Pairs (3,4), (3,5), (3,6)
    // State 9: Pairs (3,7), (4,5), (4,6)
    // State 10: Pairs (4,7), (5,6), (5,7)
    // State 11: Pairs (6,7), FINISH
    
    // Re-declaring states for clarity and better coverage
    localparam [3:0] S_IDLE    = 4'd0;
    localparam [3:0] S_LOAD    = 4'd1;
    localparam [3:0] S_PAIR_01 = 4'd2;  // (0,1), (0,2), (0,3)
    localparam [3:0] S_PAIR_04 = 4'd3;  // (0,4), (0,5), (0,6)
    localparam [3:0] S_PAIR_07 = 4'd4;  // (0,7), (1,2), (1,3)
    localparam [3:0] S_PAIR_14 = 4'd5;  // (1,4), (1,5), (1,6)
    localparam [3:0] S_PAIR_17 = 4'd6;  // (1,7), (2,3), (2,4)
    localparam [3:0] S_PAIR_25 = 4'd7;  // (2,5), (2,6), (2,7)
    localparam [3:0] S_PAIR_34 = 4'd8;  // (3,4), (3,5), (3,6)
    localparam [3:0] S_PAIR_37 = 4'd9;  // (3,7), (4,5), (4,6)
    localparam [3:0] S_PAIR_47 = 4'd10; // (4,7), (5,6), (5,7)
    localparam [3:0] S_PAIR_67 = 4'd11; // (6,7)
    localparam [3:0] S_FINISH  = 4'd12;
    
    reg [3:0] state, next_state;
    reg [15:0] threshold_reg;
    reg found_close;
    reg [2:0] i, j; // indices for pair processing
    
    // Intermediate results for each cycle
    wire [15:0] diff01, diff02, diff03;
    wire [15:0] diff04, diff05, diff06;
    wire [15:0] diff07, diff12, diff13;
    wire [15:0] diff14, diff15, diff16;
    wire [15:0] diff17, diff23, diff24;
    wire [15:0] diff25, diff26, diff27;
    wire [15:0] diff34, diff35, diff36;
    wire [15:0] diff37, diff45, diff46;
    wire [15:0] diff47, diff56, diff57;
    wire [15:0] diff67;
    
    wire cmp01, cmp02, cmp03, cmp04, cmp05, cmp06, cmp07;
    wire cmp12, cmp13, cmp14, cmp15, cmp16, cmp17;
    wire cmp23, cmp24, cmp25, cmp26, cmp27;
    wire cmp34, cmp35, cmp36, cmp37;
    wire cmp45, cmp46, cmp47;
    wire cmp56, cmp57;
    wire cmp67;

    // Absolute difference helper (combinational)
    // Function to compute absolute difference
    // Note: Icarus Verilog compatibility - no functions with unpacked arrays
    // Use direct calculation
    wire [16:0] temp01; assign temp01 = {1'b0, array_reg[0]} - {1'b0, array_reg[1]}; // borrow handling
    wire [16:0] temp01_rev; assign temp01_rev = {1'b0, array_reg[1]} - {1'b0, array_reg[0]};
    assign diff01 = (array_reg[0] > array_reg[1]) ? temp01[15:0] : temp01_rev[15:0];
    
    wire [16:0] temp02; assign temp02 = {1'b0, array_reg[0]} - {1'b0, array_reg[2]};
    wire [16:0] temp02_rev; assign temp02_rev = {1'b0, array_reg[2]} - {1'b0, array_reg[0]};
    assign diff02 = (array_reg[0] > array_reg[2]) ? temp02[15:0] : temp02_rev[15:0];
    
    wire [16:0] temp03; assign temp03 = {1'b0, array_reg[0]} - {1'b0, array_reg[3]};
    wire [16:0] temp03_rev; assign temp03_rev = {1'b0, array_reg[3]} - {1'b0, array_reg[0]};
    assign diff03 = (array_reg[0] > array_reg[3]) ? temp03[15:0] : temp03_rev[15:0];
    
    wire [16:0] temp04; assign temp04 = {1'b0, array_reg[0]} - {1'b0, array_reg[4]};
    wire [16:0] temp04_rev; assign temp04_rev = {1'b0, array_reg[4]} - {1'b0, array_reg[0]};
    assign diff04 = (array_reg[0] > array_reg[4]) ? temp04[15:0] : temp04_rev[15:0];
    
    wire [16:0] temp05; assign temp05 = {1'b0, array_reg[0]} - {1'b0, array_reg[5]};
    wire [16:0] temp05_rev; assign temp05_rev = {1'b0, array_reg[5]} - {1'b0, array_reg[0]};
    assign diff05 = (array_reg[0] > array_reg[5]) ? temp05[15:0] : temp05_rev[15:0];
    
    wire [16:0] temp06; assign temp06 = {1'b0, array_reg[0]} - {1'b0, array_reg[6]};
    wire [16:0] temp06_rev; assign temp06_rev = {1'b0, array_reg[6]} - {1'b0, array_reg[0]};
    assign diff06 = (array_reg[0] > array_reg[6]) ? temp06[15:0] : temp06_rev[15:0];
    
    wire [16:0] temp07; assign temp07 = {1'b0, array_reg[0]} - {1'b0, array_reg[7]};
    wire [16:0] temp07_rev; assign temp07_rev = {1'b0, array_reg[7]} - {1'b0, array_reg[0]};
    assign diff07 = (array_reg[0] > array_reg[7]) ? temp07[15:0] : temp07_rev[15:0];
    
    wire [16:0] temp12; assign temp12 = {1'b0, array_reg[1]} - {1'b0, array_reg[2]};
    wire [16:0] temp12_rev; assign temp12_rev = {1'b0, array_reg[2]} - {1'b0, array_reg[1]};
    assign diff12 = (array_reg[1] > array_reg[2]) ? temp12[15:0] : temp12_rev[15:0];
    
    wire [16:0] temp13; assign temp13 = {1'b0, array_reg[1]} - {1'b0, array_reg[3]};
    wire [16:0] temp13_rev; assign temp13_rev = {1'b0, array_reg[3]} - {1'b0, array_reg[1]};
    assign diff13 = (array_reg[1] > array_reg[3]) ? temp13[15:0] : temp13_rev[15:0];
    
    wire [16:0] temp14; assign temp14 = {1'b0, array_reg[1]} - {1'b0, array_reg[4]};
    wire [16:0] temp14_rev; assign temp14_rev = {1'b0, array_reg[4]} - {1'b0, array_reg[1]};
    assign diff14 = (array_reg[1] > array_reg[4]) ? temp14[15:0] : temp14_rev[15:0];
    
    wire [16:0] temp15; assign temp15 = {1'b0, array_reg[1]} - {1'b0, array_reg[5]};
    wire [16:0] temp15_rev; assign temp15_rev = {1'b0, array_reg[5]} - {1'b0, array_reg[1]};
    assign diff15 = (array_reg[1] > array_reg[5]) ? temp15[15:0] : temp15_rev[15:0];
    
    wire [16:0] temp16; assign temp16 = {1'b0, array_reg[1]} - {1'b0, array_reg[6]};
    wire [16:0] temp16_rev; assign temp16_rev = {1'b0, array_reg[6]} - {1'b0, array_reg[1]};
    assign diff16 = (array_reg[1] > array_reg[6]) ? temp16[15:0] : temp16_rev[15:0];
    
    wire [16:0] temp17; assign temp17 = {1'b0, array_reg[1]} - {1'b0, array_reg[7]};
    wire [16:0] temp17_rev; assign temp17_rev = {1'b0, array_reg[7]} - {1'b0, array_reg[1]};
    assign diff17 = (array_reg[1] > array_reg[7]) ? temp17[15:0] : temp17_rev[15:0];
    
    wire [16:0] temp23; assign temp23 = {1'b0, array_reg[2]} - {1'b0, array_reg[3]};
    wire [16:0] temp23_rev; assign temp23_rev = {1'b0, array_reg[3]} - {1'b0, array_reg[2]};
    assign diff23 = (array_reg[2] > array_reg[3]) ? temp23[15:0] : temp23_rev[15:0];
    
    wire [16:0] temp24; assign temp24 = {1'b0, array_reg[2]} - {1'b0, array_reg[4]};
    wire [16:0] temp24_rev; assign temp24_rev = {1'b0, array_reg[4]} - {1'b0, array_reg[2]};
    assign diff24 = (array_reg[2] > array_reg[4]) ? temp24[15:0] : temp24_rev[15:0];
    
    wire [16:0] temp25; assign temp25 = {1'b0, array_reg[2]} - {1'b0, array_reg[5]};
    wire [16:0] temp25_rev; assign temp25_rev = {1'b0, array_reg[5]} - {1'b0, array_reg[2]};
    assign diff25 = (array_reg[2] > array_reg[5]) ? temp25[15:0] : temp25_rev[15:0];
    
    wire [16:0] temp26; assign temp26 = {1'b0, array_reg[2]} - {1'b0, array_reg[6]};
    wire [16:0] temp26_rev; assign temp26_rev = {1'b0, array_reg[6]} - {1'b0, array_reg[2]};
    assign diff26 = (array_reg[2] > array_reg[6]) ? temp26[15:0] : temp26_rev[15:0];
    
    wire [16:0] temp27; assign temp27 = {1'b0, array_reg[2]} - {1'b0, array_reg[7]};
    wire [16:0] temp27_rev; assign temp27_rev = {1'b0, array_reg[7]} - {1'b0, array_reg[2]};
    assign diff27 = (array_reg[2] > array_reg[7]) ? temp27[15:0] : temp27_rev[15:0];
    
    wire [16:0] temp34; assign temp34 = {1'b0, array_reg[3]} - {1'b0, array_reg[4]};
    wire [16:0] temp34_rev; assign temp34_rev = {1'b0, array_reg[4]} - {1'b0, array_reg[3]};
    assign diff34 = (array_reg[3] > array_reg[4]) ? temp34[15:0] : temp34_rev[15:0];
    
    wire [16:0] temp35; assign temp35 = {1'b0, array_reg[3]} - {1'b0, array_reg[5]};
    wire [16:0] temp35_rev; assign temp35_rev = {1'b0, array_reg[5]} - {1'b0, array_reg[3]};
    assign diff35 = (array_reg[3] > array_reg[5]) ? temp35[15:0] : temp35_rev[15:0];
    
    wire [16:0] temp36; assign temp36 = {1'b0, array_reg[3]} - {1'b0, array_reg[6]};
    wire [16:0] temp36_rev; assign temp36_rev = {1'b0, array_reg[6]} - {1'b0, array_reg[3]};
    assign diff36 = (array_reg[3] > array_reg[6]) ? temp36[15:0] : temp36_rev[15:0];
    
    wire [16:0] temp37; assign temp37 = {1'b0, array_reg[3]} - {1'b0, array_reg[7]};
    wire [16:0] temp37_rev; assign temp37_rev = {1'b0, array_reg[7]} - {1'b0, array_reg[3]};
    assign diff37 = (array_reg[3] > array_reg[7]) ? temp37[15:0] : temp37_rev[15:0];
    
    wire [16:0] temp45; assign temp45 = {1'b0, array_reg[4]} - {1'b0, array_reg[5]};
    wire [16:0] temp45_rev; assign temp45_rev = {1'b0, array_reg[5]} - {1'b0, array_reg[4]};
    assign diff45 = (array_reg[4] > array_reg[5]) ? temp45[15:0] : temp45_rev[15:0];
    
    wire [16:0] temp46; assign temp46 = {1'b0, array_reg[4]} - {1'b0, array_reg[6]};
    wire [16:0] temp46_rev; assign temp46_rev = {1'b0, array_reg[6]} - {1'b0, array_reg[4]};
    assign diff46 = (array_reg[4] > array_reg[6]) ? temp46[15:0] : temp46_rev[15:0];
    
    wire [16:0] temp47; assign temp47 = {1'b0, array_reg[4]} - {1'b0, array_reg[7]};
    wire [16:0] temp47_rev; assign temp47_rev = {1'b0, array_reg[7]} - {1'b0, array_reg[4]};
    assign diff47 = (array_reg[4] > array_reg[7]) ? temp47[15:0] : temp47_rev[15:0];
    
    wire [16:0] temp56; assign temp56 = {1'b0, array_reg[5]} - {1'b0, array_reg[6]};
    wire [16:0] temp56_rev; assign temp56_rev = {1'b0, array_reg[6]} - {1'b0, array_reg[5]};
    assign diff56 = (array_reg[5] > array_reg[6]) ? temp56[15:0] : temp56_rev[15:0];
    
    wire [16:0] temp57; assign temp57 = {1'b0, array_reg[5]} - {1'b0, array_reg[7]};
    wire [16:0] temp57_rev; assign temp57_rev = {1'b0, array_reg[7]} - {1'b0, array_reg[5]};
    assign diff57 = (array_reg[5] > array_reg[7]) ? temp57[15:0] : temp57_rev[15:0];
    
    wire [16:0] temp67; assign temp67 = {1'b0, array_reg[6]} - {1'b0, array_reg[7]};
    wire [16:0] temp67_rev; assign temp67_rev = {1'b0, array_reg[7]} - {1'b0, array_reg[6]};
    assign diff67 = (array_reg[6] > array_reg[7]) ? temp67[15:0] : temp67_rev[15:0];
    
    // Comparisons
    assign cmp01 = (diff01 < threshold_reg);
    assign cmp02 = (diff02 < threshold_reg);
    assign cmp03 = (diff03 < threshold_reg);
    assign cmp04 = (diff04 < threshold_reg);
    assign cmp05 = (diff05 < threshold_reg);
    assign cmp06 = (diff06 < threshold_reg);
    assign cmp07 = (diff07 < threshold_reg);
    assign cmp12 = (diff12 < threshold_reg);
    assign cmp13 = (diff13 < threshold_reg);
    assign cmp14 = (diff14 < threshold_reg);
    assign cmp15 = (diff15 < threshold_reg);
    assign cmp16 = (diff16 < threshold_reg);
    assign cmp17 = (diff17 < threshold_reg);
    assign cmp23 = (diff23 < threshold_reg);
    assign cmp24 = (diff24 < threshold_reg);
    assign cmp25 = (diff25 < threshold_reg);
    assign cmp26 = (diff26 < threshold_reg);
    assign cmp27 = (diff27 < threshold_reg);
    assign cmp34 = (diff34 < threshold_reg);
    assign cmp35 = (diff35 < threshold_reg);
    assign cmp36 = (diff36 < threshold_reg);
    assign cmp37 = (diff37 < threshold_reg);
    assign cmp45 = (diff45 < threshold_reg);
    assign cmp46 = (diff46 < threshold_reg);
    assign cmp47 = (diff47 < threshold_reg);
    assign cmp56 = (diff56 < threshold_reg);
    assign cmp57 = (diff57 < threshold_reg);
    assign cmp67 = (diff67 < threshold_reg);

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            result <= 1'b0;
            done <= 1'b0;
            threshold_reg <= 16'd0;
            found_close <= 1'b0;
            // Initialize array to 0 (optional but good practice)
            array_reg[0] <= 16'd0;
            array_reg[1] <= 16'd0;
            array_reg[2] <= 16'd0;
            array_reg[3] <= 16'd0;
            array_reg[4] <= 16'd0;
            array_reg[5] <= 16'd0;
            array_reg[6] <= 16'd0;
            array_reg[7] <= 16'd0;
        end else begin
            // Default assignments
            done <= 1'b0;
            
            // Handle array loading independently of FSM
            if (we) begin
                array_reg[addr_in] <= data_in;
            end
            
            case (state)
                S_IDLE: begin
                    result <= 1'b0;
                    found_close <= 1'b0;
                    if (start) begin
                        state <= S_LOAD;
                        threshold_reg <= threshold; // Sample threshold
                    end
                end
                
                S_LOAD: begin
                    // Start checking pairs
                    state <= S_PAIR_01;
                end
                
                S_PAIR_01: begin
                    if (cmp01 || cmp02 || cmp03) begin
                        found_close <= 1'b1;
                    end
                    state <= S_PAIR_04;
                end
                
                S_PAIR_04: begin
                    if (cmp04 || cmp05 || cmp06) begin
                        found_close <= 1'b1;
                    end
                    state <= S_PAIR_07;
                end
                
                S_PAIR_07: begin
                    if (cmp07 || cmp12 || cmp13) begin
                        found_close <= 1'b1;
                    end
                    state <= S_PAIR_14;
                end
                
                S_PAIR_14: begin
                    if (cmp14 || cmp15 || cmp16) begin
                        found_close <= 1'b1;
                    end
                    state <= S_PAIR_17;
                end
                
                S_PAIR_17: begin
                    if (cmp17 || cmp23 || cmp24) begin
                        found_close <= 1'b1;
                    end
                    state <= S_PAIR_25;
                end
                
                S_PAIR_25: begin
                    if (cmp25 || cmp26 || cmp27) begin
                        found_close <= 1'b1;
                    end
                    state <= S_PAIR_34;
                end
                
                S_PAIR_34: begin
                    if (cmp34 || cmp35 || cmp36) begin
                        found_close <= 1'b1;
                    end
                    state <= S_PAIR_37;
                end
                
                S_PAIR_37: begin
                    if (cmp37 || cmp45 || cmp46) begin
                        found_close <= 1'b1;
                    end
                    state <= S_PAIR_47;
                end
                
                S_PAIR_47: begin
                    if (cmp47 || cmp56 || cmp57) begin
                        found_close <= 1'b1;
                    end
                    state <= S_PAIR_67;
                end
                
                S_PAIR_67: begin
                    if (cmp67) begin
                        found_close <= 1'b1;
                    end
                    state <= S_FINISH;
                end
                
                S_FINISH: begin
                    result <= found_close;
                    done <= 1'b1;
                    state <= S_IDLE;
                end
                
                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule