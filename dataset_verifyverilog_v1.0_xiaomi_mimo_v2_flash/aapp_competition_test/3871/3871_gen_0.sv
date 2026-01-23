module profit_maximizer(
    input clk, rst_n, start,
    input [2:0] num_candidates,
    input [3:0] candidate_level0, candidate_level1, candidate_level2, candidate_level3,
    input [3:0] candidate_level4, candidate_level5, candidate_level6, candidate_level7,
    input signed [15:0] candidate_cost0, candidate_cost1, candidate_cost2, candidate_cost3,
    input signed [15:0] candidate_cost4, candidate_cost5, candidate_cost6, candidate_cost7,
    input signed [15:0] profit0, profit1, profit2, profit3, profit4, profit5, profit6, profit7,
    input signed [15:0] profit8, profit9, profit10, profit11, profit12, profit13, profit14, profit15,
    output reg signed [31:0] max_profit,
    output reg done
);

    // Parameters
    localparam [3:0] MAX_LEVEL = 4'd15; // levels 0-15
    localparam [3:0] MAX_COUNT = 4'd8;  // counts 0-8
    localparam [3:0] NUM_STATES = 4'd9;
    localparam signed [31:0] NEG_INF = 32'sh80000000;
    
    // State encoding
    localparam [3:0] IDLE            = 4'd0;
    localparam [3:0] INIT            = 4'd1;
    localparam [3:0] PROCESS_CANDIDATE = 4'd2;
    localparam [3:0] UPDATE_STATE    = 4'd3;
    localparam [3:0] NEXT_COUNT      = 4'd4;
    localparam [3:0] PROPAGATE       = 4'd5;
    localparam [3:0] NEXT_CANDIDATE  = 4'd6;
    localparam [3:0] FINAL_SCAN      = 4'd7;
    localparam [3:0] DONE_STATE      = 4'd8;

    // DP table: [level][count]
    reg signed [31:0] dp00, dp01, dp02, dp03, dp04, dp05, dp06, dp07, dp08;
    reg signed [31:0] dp10, dp11, dp12, dp13, dp14, dp15, dp16, dp17, dp18;
    reg signed [31:0] dp20, dp21, dp22, dp23, dp24, dp25, dp26, dp27, dp28;
    reg signed [31:0] dp30, dp31, dp32, dp33, dp34, dp35, dp36, dp37, dp38;
    reg signed [31:0] dp40, dp41, dp42, dp43, dp44, dp45, dp46, dp47, dp48;
    reg signed [31:0] dp50, dp51, dp52, dp53, dp54, dp55, dp56, dp57, dp58;
    reg signed [31:0] dp60, dp61, dp62, dp63, dp64, dp65, dp66, dp67, dp68;
    reg signed [31:0] dp70, dp71, dp72, dp73, dp74, dp75, dp76, dp77, dp78;
    reg signed [31:0] dp80, dp81, dp82, dp83, dp84, dp85, dp86, dp87, dp88;
    reg signed [31:0] dp90, dp91, dp92, dp93, dp94, dp95, dp96, dp97, dp98;
    reg signed [31:0] dp100, dp101, dp102, dp103, dp104, dp105, dp106, dp107, dp108;
    reg signed [31:0] dp110, dp111, dp112, dp113, dp114, dp115, dp116, dp117, dp118;
    reg signed [31:0] dp120, dp121, dp122, dp123, dp124, dp125, dp126, dp127, dp128;
    reg signed [31:0] dp130, dp131, dp132, dp133, dp134, dp135, dp136, dp137, dp138;
    reg signed [31:0] dp140, dp141, dp142, dp143, dp144, dp145, dp146, dp147, dp148;
    reg signed [31:0] dp150, dp151, dp152, dp153, dp154, dp155, dp156, dp157, dp158;
    
    // Registers for state machine
    reg [3:0] state, next_state;
    reg [3:0] level_counter, count_counter, candidate_index;
    reg [3:0] current_level, current_count;
    reg signed [31:0] current_value, next_value, max_temp;
    reg [3:0] dp_write_level, dp_write_count;
    reg signed [31:0] dp_write_data;
    reg dp_write_en;
    reg [2:0] num_candidates_reg;
    
    // Intermediate signals
    wire signed [31:0] profit_val [0:15];
    wire signed [15:0] cost_val [0:7];
    wire [3:0] level_val [0:7];
    
    // Assign inputs to arrays for easier access
    assign level_val[0] = candidate_level0;
    assign level_val[1] = candidate_level1;
    assign level_val[2] = candidate_level2;
    assign level_val[3] = candidate_level3;
    assign level_val[4] = candidate_level4;
    assign level_val[5] = candidate_level5;
    assign level_val[6] = candidate_level6;
    assign level_val[7] = candidate_level7;
    
    assign cost_val[0] = candidate_cost0;
    assign cost_val[1] = candidate_cost1;
    assign cost_val[2] = candidate_cost2;
    assign cost_val[3] = candidate_cost3;
    assign cost_val[4] = candidate_cost4;
    assign cost_val[5] = candidate_cost5;
    assign cost_val[6] = candidate_cost6;
    assign cost_val[7] = candidate_cost7;
    
    assign profit_val[0] = {16'd0, profit0};
    assign profit_val[1] = {16'd0, profit1};
    assign profit_val[2] = {16'd0, profit2};
    assign profit_val[3] = {16'd0, profit3};
    assign profit_val[4] = {16'd0, profit4};
    assign profit_val[5] = {16'd0, profit5};
    assign profit_val[6] = {16'd0, profit6};
    assign profit_val[7] = {16'd0, profit7};
    assign profit_val[8] = {16'd0, profit8};
    assign profit_val[9] = {16'd0, profit9};
    assign profit_val[10] = {16'd0, profit10};
    assign profit_val[11] = {16'd0, profit11};
    assign profit_val[12] = {16'd0, profit12};
    assign profit_val[13] = {16'd0, profit13};
    assign profit_val[14] = {16'd0, profit14};
    assign profit_val[15] = {16'd0, profit15};
    
    // State transition and DP update logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            max_profit <= 0;
            level_counter <= 0;
            count_counter <= 0;
            candidate_index <= 0;
            current_level <= 0;
            current_count <= 0;
            current_value <= 0;
            next_value <= 0;
            max_temp <= NEG_INF;
            num_candidates_reg <= 0;
            
            dp00 <= 0; dp01 <= NEG_INF; dp02 <= NEG_INF; dp03 <= NEG_INF; dp04 <= NEG_INF; dp05 <= NEG_INF; dp06 <= NEG_INF; dp07 <= NEG_INF; dp08 <= NEG_INF;
            dp10 <= NEG_INF; dp11 <= NEG_INF; dp12 <= NEG_INF; dp13 <= NEG_INF; dp14 <= NEG_INF; dp15 <= NEG_INF; dp16 <= NEG_INF; dp17 <= NEG_INF; dp18 <= NEG_INF;
            dp20 <= NEG_INF; dp21 <= NEG_INF; dp22 <= NEG_INF; dp23 <= NEG_INF; dp24 <= NEG_INF; dp25 <= NEG_INF; dp26 <= NEG_INF; dp27 <= NEG_INF; dp28 <= NEG_INF;
            dp30 <= NEG_INF; dp31 <= NEG_INF; dp32 <= NEG_INF; dp33 <= NEG_INF; dp34 <= NEG_INF; dp35 <= NEG_INF; dp36 <= NEG_INF; dp37 <= NEG_INF; dp38 <= NEG_INF;
            dp40 <= NEG_INF; dp41 <= NEG_INF; dp42 <= NEG_INF; dp43 <= NEG_INF; dp44 <= NEG_INF; dp45 <= NEG_INF; dp46 <= NEG_INF; dp47 <= NEG_INF; dp48 <= NEG_INF;
            dp50 <= NEG_INF; dp51 <= NEG_INF; dp52 <= NEG_INF; dp53 <= NEG_INF; dp54 <= NEG_INF; dp55 <= NEG_INF; dp56 <= NEG_INF; dp57 <= NEG_INF; dp58 <= NEG_INF;
            dp60 <= NEG_INF; dp61 <= NEG_INF; dp62 <= NEG_INF; dp63 <= NEG_INF; dp64 <= NEG_INF; dp65 <= NEG_INF; dp66 <= NEG_INF; dp67 <= NEG_INF; dp68 <= NEG_INF;
            dp70 <= NEG_INF; dp71 <= NEG_INF; dp72 <= NEG_INF; dp73 <= NEG_INF; dp74 <= NEG_INF; dp75 <= NEG_INF; dp76 <= NEG_INF; dp77 <= NEG_INF; dp78 <= NEG_INF;
            dp80 <= NEG_INF; dp81 <= NEG_INF; dp82 <= NEG_INF; dp83 <= NEG_INF; dp84 <= NEG_INF; dp85 <= NEG_INF; dp86 <= NEG_INF; dp87 <= NEG_INF; dp88 <= NEG_INF;
            dp90 <= NEG_INF; dp91 <= NEG_INF; dp92 <= NEG_INF; dp93 <= NEG_INF; dp94 <= NEG_INF; dp95 <= NEG_INF; dp96 <= NEG_INF; dp97 <= NEG_INF; dp98 <= NEG_INF;
            dp100 <= NEG_INF; dp101 <= NEG_INF; dp102 <= NEG_INF; dp103 <= NEG_INF; dp104 <= NEG_INF; dp105 <= NEG_INF; dp106 <= NEG_INF; dp107 <= NEG_INF; dp108 <= NEG_INF;
            dp110 <= NEG_INF; dp111 <= NEG_INF; dp112 <= NEG_INF; dp113 <= NEG_INF; dp114 <= NEG_INF; dp115 <= NEG_INF; dp116 <= NEG_INF; dp117 <= NEG_INF; dp118 <= NEG_INF;
            dp120 <= NEG_INF; dp121 <= NEG_INF; dp122 <= NEG_INF; dp123 <= NEG_INF; dp124 <= NEG_INF; dp125 <= NEG_INF; dp126 <= NEG_INF; dp127 <= NEG_INF; dp128 <= NEG_INF;
            dp130 <= NEG_INF; dp131 <= NEG_INF; dp132 <= NEG_INF; dp133 <= NEG_INF; dp134 <= NEG_INF; dp135 <= NEG_INF; dp136 <= NEG_INF; dp137 <= NEG_INF; dp138 <= NEG_INF;
            dp140 <= NEG_INF; dp141 <= NEG_INF; dp142 <= NEG_INF; dp143 <= NEG_INF; dp144 <= NEG_INF; dp145 <= NEG_INF; dp146 <= NEG_INF; dp147 <= NEG_INF; dp148 <= NEG_INF;
            dp150 <= NEG_INF; dp151 <= NEG_INF; dp152 <= NEG_INF; dp153 <= NEG_INF; dp154 <= NEG_INF; dp155 <= NEG_INF; dp156 <= NEG_INF; dp157 <= NEG_INF; dp158 <= NEG_INF;
            
            dp_write_en <= 0;
            dp_write_level <= 0;
            dp_write_count <= 0;
            dp_write_data <= 0;
        end else begin
            // DP write logic
            if (dp_write_en) begin
                case (dp_write_level)
                    4'd0: begin
                        case (dp_write_count)
                            4'd0: dp00 <= dp_write_data;
                            4'd1: dp01 <= dp_write_data;
                            4'd2: dp02 <= dp_write_data;
                            4'd3: dp03 <= dp_write_data;
                            4'd4: dp04 <= dp_write_data;
                            4'd5: dp05 <= dp_write_data;
                            4'd6: dp06 <= dp_write_data;
                            4'd7: dp07 <= dp_write_data;
                            4'd8: dp08 <= dp_write_data;
                            default: ;
                        endcase
                    end
                    4'd1: begin
                        case (dp_write_count)
                            4'd0: dp10 <= dp_write_data;
                            4'd1: dp11 <= dp_write_data;
                            4'd2: dp12 <= dp_write_data;
                            4'd3: dp13 <= dp_write_data;
                            4'd4: dp14 <= dp_write_data;
                            4'd5: dp15 <= dp_write_data;
                            4'd6: dp16 <= dp_write_data;
                            4'd7: dp17 <= dp_write_data;
                            4'd8: dp18 <= dp_write_data;
                            default: ;
                        endcase
                    end
                    4'd2: begin
                        case (dp_write_count)
                            4'd0: dp20 <= dp_write_data;
                            4'd1: dp21 <= dp_write_data;
                            4'd2: dp22 <= dp_write_data;
                            4'd3: dp23 <= dp_write_data;
                            4'd4: dp24 <= dp_write_data;
                            4'd5: dp25 <= dp_write_data;
                            4'd6: dp26 <= dp_write_data;
                            4'd7: dp27 <= dp_write_data;
                            4'd8: dp28 <= dp_write_data;
                            default: ;
                        endcase
                    end
                    4'd3: begin
                        case (dp_write_count)
                            4'd0: dp30 <= dp_write_data;
                            4'd1: dp31 <= dp_write_data;
                            4'd2: dp32 <= dp_write_data;
                            4'd3: dp33 <= dp_write_data;
                            4'd4: dp34 <= dp_write_data;
                            4'd5: dp35 <= dp_write_data;
                            4'd6: dp36 <= dp_write_data;
                            4'd7: dp37 <= dp_write_data;
                            4'd8: dp38 <= dp_write_data;
                            default: ;
                        endcase
                    end
                    4'd4: begin
                        case (dp_write_count)
                            4'd0: dp40 <= dp_write_data;
                            4'd1: dp41 <= dp_write_data;
                            4'd2: dp42 <= dp_write_data;
                            4'd3: dp43 <= dp_write_data;
                            4'd4: dp44 <= dp_write_data;
                            4'd5: dp45 <= dp_write_data;
                            4'd6: dp46 <= dp_write_data;
                            4'd7: dp47 <= dp_write_data;
                            4'd8: dp48 <= dp_write_data;
                            default: ;
                        endcase
                    end
                    4'd5: begin
                        case (dp_write_count)
                            4'd0: dp50 <= dp_write_data;
                            4'd1: dp51 <= dp_write_data;
                            4'd2: dp52 <= dp_write_data;
                            4'd3: dp53 <= dp_write_data;
                            4'd4: dp54 <= dp_write_data;
                            4'd5: dp55 <= dp_write_data;
                            4'd6: dp56 <= dp_write_data;
                            4'd7: dp57 <= dp_write_data;
                            4'd8: dp58 <= dp_write_data;
                            default: ;
                        endcase
                    end
                    4'd6: begin
                        case (dp_write_count)
                            4'd0: dp60 <= dp_write_data;
                            4'd1: dp61 <= dp_write_data;
                            4'd2: dp62 <= dp_write_data;
                            4'd3: dp63 <= dp_write_data;
                            4'd4: dp64 <= dp_write_data;
                            4'd5: dp65 <= dp_write_data;
                            4'd6: dp66 <= dp_write_data;
                            4'd7: dp67 <= dp_write_data;
                            4'd8: dp68 <= dp_write_data;
                            default: ;
                        endcase
                    end
                    4'd7: begin
                        case (dp_write_count)
                            4'd0: dp70 <= dp_write_data;
                            4'd1: dp71 <= dp_write_data;
                            4'd2: dp72 <= dp_write_data;
                            4'd3: dp73 <= dp_write_data;
                            4'd4: dp74 <= dp_write_data;
                            4'd5: dp75 <= dp_write_data;
                            4'd6: dp76 <= dp_write_data;
                            4'd7: dp77 <= dp_write_data;
                            4'd8: dp78 <= dp_write_data;
                            default: ;
                        endcase
                    end
                    4'd8: begin
                        case (dp_write_count)
                            4'd0: dp80 <= dp_write_data;
                            4'd1: dp81 <= dp_write_data;
                            4'd2: dp82 <= dp_write_data;
                            4'd3: dp83 <= dp_write_data;
                            4'd4: dp84 <= dp_write_data;
                            4'd5: dp85 <= dp_write_data;
                            4'd6: dp86 <= dp_write_data;
                            4'd7: dp87 <= dp_write_data;
                            4'd8: dp88 <= dp_write_data;
                            default: ;
                        endcase
                    end
                    4'd9: begin
                        case (dp_write_count)
                            4'd0: dp90 <= dp_write_data;
                            4'd1: dp91 <= dp_write_data;
                            4'd2: dp92 <= dp_write_data;
                            4'd3: dp93 <= dp_write_data;
                            4'd4: dp94 <= dp_write_data;
                            4'd5: dp95 <= dp_write_data;
                            4'd6: dp96 <= dp_write_data;
                            4'd7: dp97 <= dp_write_data;
                            4'd8: dp98 <= dp_write_data;
                            default: ;
                        endcase
                    end
                    4'd10: begin
                        case (dp_write_count)
                            4'd0: dp100 <= dp_write_data;
                            4'd1: dp101 <= dp_write_data;
                            4'd2: dp102 <= dp_write_data;
                            4'd3: dp103 <= dp_write_data;
                            4'd4: dp104 <= dp_write_data;
                            4'd5: dp105 <= dp_write_data;
                            4'd6: dp106 <= dp_write_data;
                            4'd7: dp107 <= dp_write_data;
                            4'd8: dp108 <= dp_write_data;
                            default: ;
                        endcase
                    end
                    4'd11: begin
                        case (dp_write_count)
                            4'd0: dp110 <= dp_write_data;
                            4'd1: dp111 <= dp_write_data;
                            4'd2: dp112 <= dp_write_data;
                            4'd3: dp113 <= dp_write_data;
                            4'd4: dp114 <= dp_write_data;
                            4'd5: dp115 <= dp_write_data;
                            4'd6: dp116 <= dp_write_data;
                            4'd7: dp117 <= dp_write_data;
                            4'd8: dp118 <= dp_write_data;
                            default: ;
                        endcase
                    end
                    4'd12: begin
                        case (dp_write_count)
                            4'd0: dp120 <= dp_write_data;
                            4'd1: dp121 <= dp_write_data;
                            4'd2: dp122 <= dp_write_data;
                            4'd3: dp123 <= dp_write_data;
                            4'd4: dp124 <= dp_write_data;
                            4'd5: dp125 <= dp_write_data;
                            4'd6: dp126 <= dp_write_data;
                            4'd7: dp127 <= dp_write_data;
                            4'd8: dp128 <= dp_write_data;
                            default: ;
                        endcase
                    end
                    4'd13: begin
                        case (dp_write_count)
                            4'd0: dp130 <= dp_write_data;
                            4'd1: dp131 <= dp_write_data;
                            4'd2: dp132 <= dp_write_data;
                            4'd3: dp133 <= dp_write_data;
                            4'd4: dp134 <= dp_write_data;
                            4'd5: dp135 <= dp_write_data;
                            4'd6: dp136 <= dp_write_data;
                            4'd7: dp137 <= dp_write_data;
                            4'd8: dp138 <= dp_write_data;
                            default: ;
                        endcase
                    end
                    4'd14: begin
                        case (dp_write_count)
                            4'd0: dp140 <= dp_write_data;
                            4'd1: dp141 <= dp_write_data;
                            4'd2: dp142 <= dp_write_data;
                            4'd3: dp143 <= dp_write_data;
                            4'd4: dp144 <= dp_write_data;
                            4'd5: dp145 <= dp_write_data;
                            4'd6: dp146 <= dp_write_data;
                            4'd7: dp147 <= dp_write_data;
                            4'd8: dp148 <= dp_write_data;
                            default: ;
                        endcase
                    end
                    4'd15: begin
                        case (dp_write_count)
                            4'd0: dp150 <= dp_write_data;
                            4'd1: dp151 <= dp_write_data;
                            4'd2: dp152 <= dp_write_data;
                            4'd3: dp153 <= dp_write_data;
                            4'd4: dp154 <= dp_write_data;
                            4'd5: dp155 <= dp_write_data;
                            4'd6: dp156 <= dp_write_data;
                            4'd7: dp157 <= dp_write_data;
                            4'd8: dp158 <= dp_write_data;
                            default: ;
                        endcase
                    end
                endcase
            end
            dp_write_en <= 0;
            
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= INIT;
                        level_counter <= 0;
                        count_counter <= 0;
                        max_temp <= NEG_INF;
                        num_candidates_reg <= num_candidates;
                    end
                end
                
                INIT: begin
                    // Initialize DP table
                    if (level_counter <= MAX_LEVEL) begin
                        if (count_counter == 4'd0) begin
                            dp_write_en <= 1;
                            dp_write_level <= level_counter;
                            dp_write_count <= 0;
                            dp_write_data <= 0;
                        end else begin
                            dp_write_en <= 1;
                            dp_write_level <= level_counter;
                            dp_write_count <= count_counter;
                            dp_write_data <= NEG_INF;
                        end
                        
                        if (count_counter == MAX_COUNT) begin
                            count_counter <= 0;
                            if (level_counter == MAX_LEVEL) begin
                                candidate_index <= num_candidates_reg - 1;
                                state <= PROCESS_CANDIDATE;
                            end else begin
                                level_counter <= level_counter + 1;
                            end
                        end else begin
                            count_counter <= count_counter + 1;
                        end
                    end else begin
                        candidate_index <= num_candidates_reg - 1;
                        state <= PROCESS_CANDIDATE;
                    end
                end
                
                PROCESS_CANDIDATE: begin
                    if (candidate_index[3]) begin // candidate_index < 0 means done (bit 3 high in signed)
                        state <= FINAL_SCAN;
                        level_counter <= 0;
                        count_counter <= 0;
                    end else begin
                        current_level <= level_val[candidate_index] - 1; // convert to 0-indexed
                        count_counter <= MAX_COUNT;
                        state <= UPDATE_STATE;
                    end
                end
                
                UPDATE_STATE: begin
                    if (count_counter[3]) begin // count < 0, done with this candidate
                        state <= NEXT_CANDIDATE;
                    end else begin
                        // Read dp[current_level][count_counter]
                        case ({current_level, count_counter})
                            {4'd0, 4'd0}: begin if (dp00 > NEG_INF) begin next_value <= dp00 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd0, 4'd1}: begin if (dp01 > NEG_INF) begin next_value <= dp01 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd0, 4'd2}: begin if (dp02 > NEG_INF) begin next_value <= dp02 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd0, 4'd3}: begin if (dp03 > NEG_INF) begin next_value <= dp03 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd0, 4'd4}: begin if (dp04 > NEG_INF) begin next_value <= dp04 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd0, 4'd5}: begin if (dp05 > NEG_INF) begin next_value <= dp05 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd0, 4'd6}: begin if (dp06 > NEG_INF) begin next_value <= dp06 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd0, 4'd7}: begin if (dp07 > NEG_INF) begin next_value <= dp07 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd0, 4'd8}: begin if (dp08 > NEG_INF) begin next_value <= dp08 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd1, 4'd0}: begin if (dp10 > NEG_INF) begin next_value <= dp10 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd1, 4'd1}: begin if (dp11 > NEG_INF) begin next_value <= dp11 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd1, 4'd2}: begin if (dp12 > NEG_INF) begin next_value <= dp12 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd1, 4'd3}: begin if (dp13 > NEG_INF) begin next_value <= dp13 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd1, 4'd4}: begin if (dp14 > NEG_INF) begin next_value <= dp14 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd1, 4'd5}: begin if (dp15 > NEG_INF) begin next_value <= dp15 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd1, 4'd6}: begin if (dp16 > NEG_INF) begin next_value <= dp16 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd1, 4'd7}: begin if (dp17 > NEG_INF) begin next_value <= dp17 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd1, 4'd8}: begin if (dp18 > NEG_INF) begin next_value <= dp18 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd2, 4'd0}: begin if (dp20 > NEG_INF) begin next_value <= dp20 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd2, 4'd1}: begin if (dp21 > NEG_INF) begin next_value <= dp21 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd2, 4'd2}: begin if (dp22 > NEG_INF) begin next_value <= dp22 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd2, 4'd3}: begin if (dp23 > NEG_INF) begin next_value <= dp23 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd2, 4'd4}: begin if (dp24 > NEG_INF) begin next_value <= dp24 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd2, 4'd5}: begin if (dp25 > NEG_INF) begin next_value <= dp25 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd2, 4'd6}: begin if (dp26 > NEG_INF) begin next_value <= dp26 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd2, 4'd7}: begin if (dp27 > NEG_INF) begin next_value <= dp27 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd2, 4'd8}: begin if (dp28 > NEG_INF) begin next_value <= dp28 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd3, 4'd0}: begin if (dp30 > NEG_INF) begin next_value <= dp30 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd3, 4'd1}: begin if (dp31 > NEG_INF) begin next_value <= dp31 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd3, 4'd2}: begin if (dp32 > NEG_INF) begin next_value <= dp32 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd3, 4'd3}: begin if (dp33 > NEG_INF) begin next_value <= dp33 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd3, 4'd4}: begin if (dp34 > NEG_INF) begin next_value <= dp34 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd3, 4'd5}: begin if (dp35 > NEG_INF) begin next_value <= dp35 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd3, 4'd6}: begin if (dp36 > NEG_INF) begin next_value <= dp36 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd3, 4'd7}: begin if (dp37 > NEG_INF) begin next_value <= dp37 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd3, 4'd8}: begin if (dp38 > NEG_INF) begin next_value <= dp38 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd4, 4'd0}: begin if (dp40 > NEG_INF) begin next_value <= dp40 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd4, 4'd1}: begin if (dp41 > NEG_INF) begin next_value <= dp41 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd4, 4'd2}: begin if (dp42 > NEG_INF) begin next_value <= dp42 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd4, 4'd3}: begin if (dp43 > NEG_INF) begin next_value <= dp43 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd4, 4'd4}: begin if (dp44 > NEG_INF) begin next_value <= dp44 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd4, 4'd5}: begin if (dp45 > NEG_INF) begin next_value <= dp45 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd4, 4'd6}: begin if (dp46 > NEG_INF) begin next_value <= dp46 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd4, 4'd7}: begin if (dp47 > NEG_INF) begin next_value <= dp47 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd4, 4'd8}: begin if (dp48 > NEG_INF) begin next_value <= dp48 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd5, 4'd0}: begin if (dp50 > NEG_INF) begin next_value <= dp50 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd5, 4'd1}: begin if (dp51 > NEG_INF) begin next_value <= dp51 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd5, 4'd2}: begin if (dp52 > NEG_INF) begin next_value <= dp52 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd5, 4'd3}: begin if (dp53 > NEG_INF) begin next_value <= dp53 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd5, 4'd4}: begin if (dp54 > NEG_INF) begin next_value <= dp54 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd5, 4'd5}: begin if (dp55 > NEG_INF) begin next_value <= dp55 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd5, 4'd6}: begin if (dp56 > NEG_INF) begin next_value <= dp56 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd5, 4'd7}: begin if (dp57 > NEG_INF) begin next_value <= dp57 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd5, 4'd8}: begin if (dp58 > NEG_INF) begin next_value <= dp58 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd6, 4'd0}: begin if (dp60 > NEG_INF) begin next_value <= dp60 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd6, 4'd1}: begin if (dp61 > NEG_INF) begin next_value <= dp61 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd6, 4'd2}: begin if (dp62 > NEG_INF) begin next_value <= dp62 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd6, 4'd3}: begin if (dp63 > NEG_INF) begin next_value <= dp63 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd6, 4'd4}: begin if (dp64 > NEG_INF) begin next_value <= dp64 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd6, 4'd5}: begin if (dp65 > NEG_INF) begin next_value <= dp65 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd6, 4'd6}: begin if (dp66 > NEG_INF) begin next_value <= dp66 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd6, 4'd7}: begin if (dp67 > NEG_INF) begin next_value <= dp67 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd6, 4'd8}: begin if (dp68 > NEG_INF) begin next_value <= dp68 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd7, 4'd0}: begin if (dp70 > NEG_INF) begin next_value <= dp70 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd7, 4'd1}: begin if (dp71 > NEG_INF) begin next_value <= dp71 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd7, 4'd2}: begin if (dp72 > NEG_INF) begin next_value <= dp72 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd7, 4'd3}: begin if (dp73 > NEG_INF) begin next_value <= dp73 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd7, 4'd4}: begin if (dp74 > NEG_INF) begin next_value <= dp74 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd7, 4'd5}: begin if (dp75 > NEG_INF) begin next_value <= dp75 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd7, 4'd6}: begin if (dp76 > NEG_INF) begin next_value <= dp76 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd7, 4'd7}: begin if (dp77 > NEG_INF) begin next_value <= dp77 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd7, 4'd8}: begin if (dp78 > NEG_INF) begin next_value <= dp78 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd8, 4'd0}: begin if (dp80 > NEG_INF) begin next_value <= dp80 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd8, 4'd1}: begin if (dp81 > NEG_INF) begin next_value <= dp81 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd8, 4'd2}: begin if (dp82 > NEG_INF) begin next_value <= dp82 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd8, 4'd3}: begin if (dp83 > NEG_INF) begin next_value <= dp83 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd8, 4'd4}: begin if (dp84 > NEG_INF) begin next_value <= dp84 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd8, 4'd5}: begin if (dp85 > NEG_INF) begin next_value <= dp85 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd8, 4'd6}: begin if (dp86 > NEG_INF) begin next_value <= dp86 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd8, 4'd7}: begin if (dp87 > NEG_INF) begin next_value <= dp87 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd8, 4'd8}: begin if (dp88 > NEG_INF) begin next_value <= dp88 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd9, 4'd0}: begin if (dp90 > NEG_INF) begin next_value <= dp90 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd9, 4'd1}: begin if (dp91 > NEG_INF) begin next_value <= dp91 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd9, 4'd2}: begin if (dp92 > NEG_INF) begin next_value <= dp92 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd9, 4'd3}: begin if (dp93 > NEG_INF) begin next_value <= dp93 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd9, 4'd4}: begin if (dp94 > NEG_INF) begin next_value <= dp94 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd9, 4'd5}: begin if (dp95 > NEG_INF) begin next_value <= dp95 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd9, 4'd6}: begin if (dp96 > NEG_INF) begin next_value <= dp96 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd9, 4'd7}: begin if (dp97 > NEG_INF) begin next_value <= dp97 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd9, 4'd8}: begin if (dp98 > NEG_INF) begin next_value <= dp98 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd10, 4'd0}: begin if (dp100 > NEG_INF) begin next_value <= dp100 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd10, 4'd1}: begin if (dp101 > NEG_INF) begin next_value <= dp101 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd10, 4'd2}: begin if (dp102 > NEG_INF) begin next_value <= dp102 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd10, 4'd3}: begin if (dp103 > NEG_INF) begin next_value <= dp103 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd10, 4'd4}: begin if (dp104 > NEG_INF) begin next_value <= dp104 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd10, 4'd5}: begin if (dp105 > NEG_INF) begin next_value <= dp105 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd10, 4'd6}: begin if (dp106 > NEG_INF) begin next_value <= dp106 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd10, 4'd7}: begin if (dp107 > NEG_INF) begin next_value <= dp107 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd10, 4'd8}: begin if (dp108 > NEG_INF) begin next_value <= dp108 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd11, 4'd0}: begin if (dp110 > NEG_INF) begin next_value <= dp110 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd11, 4'd1}: begin if (dp111 > NEG_INF) begin next_value <= dp111 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd11, 4'd2}: begin if (dp112 > NEG_INF) begin next_value <= dp112 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd11, 4'd3}: begin if (dp113 > NEG_INF) begin next_value <= dp113 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd11, 4'd4}: begin if (dp114 > NEG_INF) begin next_value <= dp114 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd11, 4'd5}: begin if (dp115 > NEG_INF) begin next_value <= dp115 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd11, 4'd6}: begin if (dp116 > NEG_INF) begin next_value <= dp116 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd11, 4'd7}: begin if (dp117 > NEG_INF) begin next_value <= dp117 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd11, 4'd8}: begin if (dp118 > NEG_INF) begin next_value <= dp118 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd12, 4'd0}: begin if (dp120 > NEG_INF) begin next_value <= dp120 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd12, 4'd1}: begin if (dp121 > NEG_INF) begin next_value <= dp121 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd12, 4'd2}: begin if (dp122 > NEG_INF) begin next_value <= dp122 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd12, 4'd3}: begin if (dp123 > NEG_INF) begin next_value <= dp123 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd12, 4'd4}: begin if (dp124 > NEG_INF) begin next_value <= dp124 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd12, 4'd5}: begin if (dp125 > NEG_INF) begin next_value <= dp125 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd12, 4'd6}: begin if (dp126 > NEG_INF) begin next_value <= dp126 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd12, 4'd7}: begin if (dp127 > NEG_INF) begin next_value <= dp127 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd12, 4'd8}: begin if (dp128 > NEG_INF) begin next_value <= dp128 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd13, 4'd0}: begin if (dp130 > NEG_INF) begin next_value <= dp130 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd13, 4'd1}: begin if (dp131 > NEG_INF) begin next_value <= dp131 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd13, 4'd2}: begin if (dp132 > NEG_INF) begin next_value <= dp132 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd13, 4'd3}: begin if (dp133 > NEG_INF) begin next_value <= dp133 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd13, 4'd4}: begin if (dp134 > NEG_INF) begin next_value <= dp134 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd13, 4'd5}: begin if (dp135 > NEG_INF) begin next_value <= dp135 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd13, 4'd6}: begin if (dp136 > NEG_INF) begin next_value <= dp136 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd13, 4'd7}: begin if (dp137 > NEG_INF) begin next_value <= dp137 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd13, 4'd8}: begin if (dp138 > NEG_INF) begin next_value <= dp138 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd14, 4'd0}: begin if (dp140 > NEG_INF) begin next_value <= dp140 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd14, 4'd1}: begin if (dp141 > NEG_INF) begin next_value <= dp141 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd14, 4'd2}: begin if (dp142 > NEG_INF) begin next_value <= dp142 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd14, 4'd3}: begin if (dp143 > NEG_INF) begin next_value <= dp143 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd14, 4'd4}: begin if (dp144 > NEG_INF) begin next_value <= dp144 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd14, 4'd5}: begin if (dp145 > NEG_INF) begin next_value <= dp145 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd14, 4'd6}: begin if (dp146 > NEG_INF) begin next_value <= dp146 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd14, 4'd7}: begin if (dp147 > NEG_INF) begin next_value <= dp147 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd14, 4'd8}: begin if (dp148 > NEG_INF) begin next_value <= dp148 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd15, 4'd0}: begin if (dp150 > NEG_INF) begin next_value <= dp150 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd15, 4'd1}: begin if (dp151 > NEG_INF) begin next_value <= dp151 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd15, 4'd2}: begin if (dp152 > NEG_INF) begin next_value <= dp152 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd15, 4'd3}: begin if (dp153 > NEG_INF) begin next_value <= dp153 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd15, 4'd4}: begin if (dp154 > NEG_INF) begin next_value <= dp154 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd15, 4'd5}: begin if (dp155 > NEG_INF) begin next_value <= dp155 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd15, 4'd6}: begin if (dp156 > NEG_INF) begin next_value <= dp156 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd15, 4'd7}: begin if (dp157 > NEG_INF) begin next_value <= dp157 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            {4'd15, 4'd8}: begin if (dp158 > NEG_INF) begin next_value <= dp158 - {16'd0, cost_val[candidate_index]} + profit_val[current_level]; current_count <= count_counter + 1; state <= NEXT_COUNT; end else begin count_counter <= count_counter - 1; state <= UPDATE_STATE; end end
                            default: begin
                                // Should not happen
                                count_counter <= count_counter - 1;
                                state <= UPDATE_STATE;
                            end
                        endcase
                    end
                end
                
                NEXT_COUNT: begin
                    if (next_value > max_temp) begin
                        max_temp <= next_value;
                    end
                    // Update dp[current_level][current_count]
                    dp_write_en <= 1;
                    dp_write_level <= current_level;
                    dp_write_count <= current_count;
                    dp_write_data <= next_value;
                    current_value <= next_value;
                    state <= PROPAGATE;
                end
                
                PROPAGATE: begin
                    if (current_count >= 2 && current_level < MAX_LEVEL) begin
                        // Propagate fight merging
                        next_value <= current_value + (current_count >> 1) * profit_val[current_level + 1];
                        current_count <= current_count >> 1;
                        current_level <= current_level + 1;
                        state <= NEXT_COUNT;
                    end else begin
                        count_counter <= count_counter - 1;
                        state <= UPDATE_STATE;
                    end
                end
                
                NEXT_CANDIDATE: begin
                    if (candidate_index == 0) begin
                        state <= FINAL_SCAN;
                        level_counter <= 0;
                        count_counter <= 0;
                    end else begin
                        candidate_index <= candidate_index - 1;
                        state <= PROCESS_CANDIDATE;
                    end
                end
                
                FINAL_SCAN: begin
                    if (level_counter <= MAX_LEVEL) begin
                        if (count_counter <= MAX_COUNT) begin
                            // Read dp[level_counter][count_counter]
                            case ({level_counter, count_counter})
                                {4'd0, 4'd0}: if (dp00 > max_temp) max_temp <= dp00;
                                {4'd0, 4'd1}: if (dp01 > max_temp) max_temp <= dp01;
                                {4'd0, 4'd2}: if (dp02 > max_temp) max_temp <= dp02;
                                {4'd0, 4'd3}: if (dp03 > max_temp) max_temp <= dp03;
                                {4'd0, 4'd4}: if (dp04 > max_temp) max_temp <= dp04;
                                {4'd0, 4'd5}: if (dp05 > max_temp) max_temp <= dp05;
                                {4'd0, 4'd6}: if (dp06 > max_temp) max_temp <= dp06;
                                {4'd0, 4'd7}: if (dp07 > max_temp) max_temp <= dp07;
                                {4'd0, 4'd8}: if (dp08 > max_temp) max_temp <= dp08;
                                {4'd1, 4'd0}: if (dp10 > max_temp) max_temp <= dp10;
                                {4'd1, 4'd1}: if (dp11 > max_temp) max_temp <= dp11;
                                {4'd1, 4'd2}: if (dp12 > max_temp) max_temp <= dp12;
                                {4'd1, 4'd3}: if (dp13 > max_temp) max_temp <= dp13;
                                {4'd1, 4'd4}: if (dp14 > max_temp) max_temp <= dp14;
                                {4'd1, 4'd5}: if (dp15 > max_temp) max_temp <= dp15;
                                {4'd1, 4'd6}: if (dp16 > max_temp) max_temp <= dp16;
                                {4'd1, 4'd7}: if (dp17 > max_temp) max_temp <= dp17;
                                {4'd1, 4'd8}: if (dp18 > max_temp) max_temp <= dp18;
                                {4'd2, 4'd0}: if (dp20 > max_temp) max_temp <= dp20;
                                {4'd2, 4'd1}: if (dp21 > max_temp) max_temp <= dp21;
                                {4'd2, 4'd2}: if (dp22 > max_temp) max_temp <= dp22;
                                {4'd2, 4'd3}: if (dp23 > max_temp) max_temp <= dp23;
                                {4'd2, 4'd4}: if (dp24 > max_temp) max_temp <= dp24;
                                {4'd2, 4'd5}: if (dp25 > max_temp) max_temp <= dp25;
                                {4'd2, 4'd6}: if (dp26 > max_temp) max_temp <= dp26;
                                {4'd2, 4'd7}: if (dp27 > max_temp) max_temp <= dp27;
                                {4'd2, 4'd8}: if (dp28 > max_temp) max_temp <= dp28;
                                {4'd3, 4'd0}: if (dp30 > max_temp) max_temp <= dp30;
                                {4'd3, 4'd1}: if (dp31 > max_temp) max_temp <= dp31;
                                {4'd3, 4'd2}: if (dp32 > max_temp) max_temp <= dp32;
                                {4'd3, 4'd3}: if (dp33 > max_temp) max_temp <= dp33;
                                {4'd3, 4'd4}: if (dp34 > max_temp) max_temp <= dp34;
                                {4'd3, 4'd5}: if (dp35 > max_temp) max_temp <= dp35;
                                {4'd3, 4'd6}: if (dp36 > max_temp) max_temp <= dp36;
                                {4'd3, 4'd7}: if (dp37 > max_temp) max_temp <= dp37;
                                {4'd3, 4'd8}: if (dp38 > max_temp) max_temp <= dp38;
                                {4'd4, 4'd0}: if (dp40 > max_temp) max_temp <= dp40;
                                {4'd4, 4'd1}: if (dp41 > max_temp) max_temp <= dp41;
                                {4'd4, 4'd2}: if (dp42 > max_temp) max_temp <= dp42;
                                {4'd4, 4'd3}: if (dp43 > max_temp) max_temp <= dp43;
                                {4'd4, 4'd4}: if (dp44 > max_temp) max_temp <= dp44;
                                {4'd4, 4'd5}: if (dp45 > max_temp) max_temp <= dp45;
                                {4'd4, 4'd6}: if (dp46 > max_temp) max_temp <= dp46;
                                {4'd4, 4'd7}: if (dp47 > max_temp) max_temp <= dp47;
                                {4'd4, 4'd8}: if (dp48 > max_temp) max_temp <= dp48;
                                {4'd5, 4'd0}: if (dp50 > max_temp) max_temp <= dp50;
                                {4'd5, 4'd1}: if (dp51 > max_temp) max_temp <= dp51;
                                {4'd5, 4'd2}: if (dp52 > max_temp) max_temp <= dp52;
                                {4'd5, 4'd3}: if (dp53 > max_temp) max_temp <= dp53;
                                {4'd5, 4'd4}: if (dp54 > max_temp) max_temp <= dp54;
                                {4'd5, 4'd5}: if (dp55 > max_temp) max_temp <= dp55;
                                {4'd5, 4'd6}: if (dp56 > max_temp) max_temp <= dp56;
                                {4'd5, 4'd7}: if (dp57 > max_temp) max_temp <= dp57;
                                {4'd5, 4'd8}: if (dp58 > max_temp) max_temp <= dp58;
                                {4'd6, 4'd0}: if (dp60 > max_temp) max_temp <= dp60;
                                {4'd6, 4'd1}: if (dp61 > max_temp) max_temp <= dp61;
                                {4'd6, 4'd2}: if (dp62 > max_temp) max_temp <= dp62;
                                {4'd6, 4'd3}: if (dp63 > max_temp) max_temp <= dp63;
                                {4'd6, 4'd4}: if (dp64 > max_temp) max_temp <= dp64;
                                {4'd6, 4'd5}: if (dp65 > max_temp) max_temp <= dp65;
                                {4'd6, 4'd6}: if (dp66 > max_temp) max_temp <= dp66;
                                {4'd6, 4'd7}: if (dp67 > max_temp) max_temp <= dp67;
                                {4'd6, 4'd8}: if (dp68 > max_temp) max_temp <= dp68;
                                {4'd7, 4'd0}: if (dp70 > max_temp) max_temp <= dp70;
                                {4'd7, 4'd1}: if (dp71 > max_temp) max_temp <= dp71;
                                {4'd7, 4'd2}: if (dp72 > max_temp) max_temp <= dp72;
                                {4'd7, 4'd3}: if (dp73 > max_temp) max_temp <= dp73;
                                {4'd7, 4'd4}: if (dp74 > max_temp) max_temp <= dp74;
                                {4'd7, 4'd5}: if (dp75 > max_temp) max_temp <= dp75;
                                {4'd7, 4'd6}: if (dp76 > max_temp) max_temp <= dp76;
                                {4'd7, 4'd7}: if (dp77 > max_temp) max_temp <= dp77;
                                {4'd7, 4'd8}: if (dp78 > max_temp) max_temp <= dp78;
                                {4'd8, 4'd0}: if (dp80 > max_temp) max_temp <= dp80;
                                {4'd8, 4'd1}: if (dp81 > max_temp) max_temp <= dp81;
                                {4'd8, 4'd2}: if (dp82 > max_temp) max_temp <= dp82;
                                {4'd8, 4'd3}: if (dp83 > max_temp) max_temp <= dp83;
                                {4'd8, 4'd4}: if (dp84 > max_temp) max_temp <= dp84;
                                {4'd8, 4'd5}: if (dp85 > max_temp) max_temp <= dp85;
                                {4'd8, 4'd6}: if (dp86 > max_temp) max_temp <= dp86;
                                {4'd8, 4'd7}: if (dp87 > max_temp) max_temp <= dp87;
                                {4'd8, 4'd8}: if (dp88 > max_temp) max_temp <= dp88;
                                {4'd9, 4'd0}: if (dp90 > max_temp) max_temp <= dp90;
                                {4'd9, 4'd1}: if (dp91 > max_temp) max_temp <= dp91;
                                {4'd9, 4'd2}: if (dp92 > max_temp) max_temp <= dp92;
                                {4'd9, 4'd3}: if (dp93 > max_temp) max_temp <= dp93;
                                {4'd9, 4'd4}: if (dp94 > max_temp) max_temp <= dp94;
                                {4'd9, 4'd5}: if (dp95 > max_temp) max_temp <= dp95;
                                {4'd9, 4'd6}: if (dp96 > max_temp) max_temp <= dp96;
                                {4'd9, 4'd7}: if (dp97 > max_temp) max_temp <= dp97;
                                {4'd9, 4'd8}: if (dp98 > max_temp) max_temp <= dp98;
                                {4'd10, 4'd0}: if (dp100 > max_temp) max_temp <= dp100;
                                {4'd10, 4'd1}: if (dp101 > max_temp) max_temp <= dp101;
                                {4'd10, 4'd2}: if (dp102 > max_temp) max_temp <= dp102;
                                {4'd10, 4'd3}: if (dp103 > max_temp) max_temp <= dp103;
                                {4'd10, 4'd4}: if (dp104 > max_temp) max_temp <= dp104;
                                {4'd10, 4'd5}: if (dp105 > max_temp) max_temp <= dp105;
                                {4'd10, 4'd6}: if (dp106 > max_temp) max_temp <= dp106;
                                {4'd10, 4'd7}: if (dp107 > max_temp) max_temp <= dp107;
                                {4'd10, 4'd8}: if (dp108 > max_temp) max_temp <= dp108;
                                {4'd11, 4'd0}: if (dp110 > max_temp) max_temp <= dp110;
                                {4'd11, 4'd1}: if (dp111 > max_temp) max_temp <= dp111;
                                {4'd11, 4'd2}: if (dp112 > max_temp) max_temp <= dp112;
                                {4'd11, 4'd3}: if (dp113 > max_temp) max_temp <= dp113;
                                {4'd11, 4'd4}: if (dp114 > max_temp) max_temp <= dp114;
                                {4'd11, 4'd5}: if (dp115 > max_temp) max_temp <= dp115;
                                {4'd11, 4'd6}: if (dp116 > max_temp) max_temp <= dp116;
                                {4'd11, 4'd7}: if (dp117 > max_temp) max_temp <= dp117;
                                {4'd11, 4'd8}: if (dp118 > max_temp) max_temp <= dp118;
                                {4'd12, 4'd0}: if (dp120 > max_temp) max_temp <= dp120;
                                {4'd12, 4'd1}: if (dp121 > max_temp) max_temp <= dp121;
                                {4'd12, 4'd2}: if (dp122 > max_temp) max_temp <= dp122;
                                {4'd12, 4'd3}: if (dp123 > max_temp) max_temp <= dp123;
                                {4'd12, 4'd4}: if (dp124 > max_temp) max_temp <= dp124;
                                {4'd12, 4'd5}: if (dp125 > max_temp) max_temp <= dp125;
                                {4'd12, 4'd6}: if (dp126 > max_temp) max_temp <= dp126;
                                {4'd12, 4'd7}: if (dp127 > max_temp) max_temp <= dp127;
                                {4'd12, 4'd8}: if (dp128 > max_temp) max_temp <= dp128;
                                {4'd13, 4'd0}: if (dp130 > max_temp) max_temp <= dp130;
                                {4'd13, 4'd1}: if (dp131 > max_temp) max_temp <= dp131;
                                {4'd13, 4'd2}: if (dp132 > max_temp) max_temp <= dp132;
                                {4'd13, 4'd3}: if (dp133 > max_temp) max_temp <= dp133;
                                {4'd13, 4'd4}: if (dp134 > max_temp) max_temp <= dp134;
                                {4'd13, 4'd5}: if (dp135 > max_temp) max_temp <= dp135;
                                {4'd13, 4'd6}: if (dp136 > max_temp) max_temp <= dp136;
                                {4'd13, 4'd7}: if (dp137 > max_temp) max_temp <= dp137;
                                {4'd13, 4'd8}: if (dp138 > max_temp) max_temp <= dp138;
                                {4'd14, 4'd0}: if (dp140 > max_temp) max_temp <= dp140;
                                {4'd14, 4'd1}: if (dp141 > max_temp) max_temp <= dp141;
                                {4'd14, 4'd2}: if (dp142 > max_temp) max_temp <= dp142;
                                {4'd14, 4'd3}: if (dp143 > max_temp) max_temp <= dp143;
                                {4'd14, 4'd4}: if (dp144 > max_temp) max_temp <= dp144;
                                {4'd14, 4'd5}: if (dp145 > max_temp) max_temp <= dp145;
                                {4'd14, 4'd6}: if (dp146 > max_temp) max_temp <= dp146;
                                {4'd14, 4'd7}: if (dp147 > max_temp) max_temp <= dp147;
                                {4'd14, 4'd8}: if (dp148 > max_temp) max_temp <= dp148;
                                {4'd15, 4'd0}: if (dp150 > max_temp) max_temp <= dp150;
                                {4'd15, 4'd1}: if (dp151 > max_temp) max_temp <= dp151;
                                {4'd15, 4'd2}: if (dp152 > max_temp) max_temp <= dp152;
                                {4'd15, 4'd3}: if (dp153 > max_temp) max_temp <= dp153;
                                {4'd15, 4'd4}: if (dp154 > max_temp) max_temp <= dp154;
                                {4'd15, 4'd5}: if (dp155 > max_temp) max_temp <= dp155;
                                {4'd15, 4'd6}: if (dp156 > max_temp) max_temp <= dp156;
                                {4'd15, 4'd7}: if (dp157 > max_temp) max_temp <= dp157;
                                {4'd15, 4'd8}: if (dp158 > max_temp) max_temp <= dp158;
                                default: ;
                            endcase
                            
                            if (count_counter == MAX_COUNT) begin
                                count_counter <= 0;
                                level_counter <= level_counter + 1;
                            end else begin
                                count_counter <= count_counter + 1;
                            end
                        end else begin
                            count_counter <= 0;
                            level_counter <= level_counter + 1;
                        end
                    end else begin
                        max_profit <= max_temp;
                        done <= 1;
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
